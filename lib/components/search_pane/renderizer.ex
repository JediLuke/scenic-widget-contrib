defmodule ScenicWidgets.SearchPane.Renderizer do
  @moduledoc """
  Draws `ScenicWidgets.SearchPane`.

  ## Why this is incremental

  It used to rebuild the whole graph on every change, on the grounds that a
  sidebar's worth of content is small enough not to be worth the bookkeeping.
  That is true right up until the pane wants to contain a **component** — a
  TextField for its query, say — because a graph built from scratch takes the
  component with it, and a child that is destroyed and recreated on every
  keystroke loses its cursor, its selection and its input registration.

  So the pane is drawn as four independent pieces, and a change replaces only
  the pieces it actually affects:

      :search_pane_background   the pane's own rect            (theme/frame)
      :search_pane_chrome       header backdrop, title, close  (theme/frame)
      :search_pane_widgets      fields, toggles, status        (typing, results)
      :search_pane_body         result rows and scrollbars     (results, hover)

  None of the four overlap another, so replacing one and letting it land at
  the end of the graph cannot put it over the top of something it should be
  under. Anything that does not fit that — a change of theme or frame —
  rebuilds the lot, which is rare enough to be free.
  """

  use Widgex.Scrollable, direction: :vertical

  alias Scenic.Graph
  alias Scenic.Primitives
  alias ScenicWidgets.SearchPane.State

  # Where a match's highlight rectangle sits relative to the text baseline.
  @highlight_top 3

  @doc "The whole pane, from nothing. Used on init and nowhere else."
  def render(%State{} = state) do
    Graph.build()
    |> render_backdrop(state)
    |> render_widgets(state)
    |> render_fields(state)
    |> render_body(state)
  end

  # Everything the live widgets sit ON TOP of. Each piece carries an id and is
  # modified in place rather than replaced, because a replacement lands at the
  # END of the graph — and a backdrop drawn last is a backdrop drawn over the
  # things it is supposed to be behind.
  defp render_backdrop(graph, %State{theme: theme} = state) do
    height = State.header_height(state)
    width = state.frame.size.width
    close = Enum.find(State.header_widgets(state), &(&1.id == :close))

    graph
    |> Primitives.rect(state.frame.size.box,
      id: :search_pane_background,
      fill: theme.background,
      stroke: {1, theme.border},
      input: [:cursor_button, :cursor_pos]
    )
    |> Primitives.rect({width, height}, id: :search_pane_header_bg, fill: theme.header_background)
    |> Primitives.line({{0, height}, {width, height}},
      id: :search_pane_header_rule,
      stroke: {1, theme.border}
    )
    |> Primitives.text("SEARCH",
      id: :search_pane_title,
      translate: {theme.padding, theme.padding + theme.row_height - 6},
      fill: theme.heading,
      font: theme.font,
      font_size: theme.small_font_size
    )
    |> Primitives.text("×",
      id: :search_pane_close_glyph,
      translate: {close.x + 4, close.y + close.h - 6},
      fill: theme.dim_text,
      font: theme.font,
      font_size: theme.font_size
    )
  end

  defp update_backdrop(graph, %State{theme: theme} = state) do
    height = State.header_height(state)
    width = state.frame.size.width
    close = Enum.find(State.header_widgets(state), &(&1.id == :close))

    graph
    |> Graph.modify(:search_pane_background, fn p ->
      Primitives.rect(p, state.frame.size.box, fill: theme.background, stroke: {1, theme.border})
    end)
    |> Graph.modify(:search_pane_header_bg, fn p ->
      Primitives.rect(p, {width, height}, fill: theme.header_background)
    end)
    |> Graph.modify(:search_pane_header_rule, fn p ->
      Primitives.line(p, {{0, height}, {width, height}}, stroke: {1, theme.border})
    end)
    |> Graph.modify(:search_pane_title, fn p ->
      Primitives.text(p, "SEARCH",
        translate: {theme.padding, theme.padding + theme.row_height - 6},
        fill: theme.heading,
        font_size: theme.small_font_size
      )
    end)
    |> Graph.modify(:search_pane_close_glyph, fn p ->
      Primitives.text(p, "×",
        translate: {close.x + 4, close.y + close.h - 6},
        fill: theme.dim_text,
        font_size: theme.font_size
      )
    end)
  end

  @doc """
  Redraw only what changed between two states.

  The pane is drawn as four sibling pieces (see the moduledoc); this replaces
  the ones the change touched and leaves the rest — and anything living
  alongside them — alone.
  """
  def update_render(graph, %State{} = old_state, %State{} = new_state) do
    moved? = geometry_changed?(old_state, new_state)

    graph
    |> then(fn g -> if moved?, do: update_backdrop(g, new_state), else: g end)
    |> maybe_replace(
      :search_pane_widgets,
      moved? or widgets_changed?(old_state, new_state),
      &render_widgets(&1, new_state)
    )
    |> maybe_replace(
      :search_pane_body,
      moved? or body_changed?(old_state, new_state),
      &render_body(&1, new_state)
    )
    |> then(fn g -> if moved?, do: move_fields(g, new_state), else: g end)
  end

  defp maybe_replace(graph, _id, false, _render), do: graph

  defp maybe_replace(graph, id, true, render) do
    graph |> Graph.delete(id) |> render.()
  end

  # A different theme or a different frame moves or recolours everything. It
  # arrives on every mouse move while the sidebar divider is being dragged, so
  # it has to be as cheap as it can be — and in particular must not disturb
  # anything living in the graph alongside these pieces.
  defp geometry_changed?(old_state, new_state),
    do: old_state.theme != new_state.theme or old_state.frame != new_state.frame

  # Everything the header's live widgets are drawn from. A search changes the
  # status line, a click changes a toggle. Typing is NOT here: the fields draw
  # themselves, so a keystroke costs this module nothing at all.
  defp widgets_changed?(old_state, new_state) do
    widget_signature(old_state) != widget_signature(new_state)
  end

  defp widget_signature(%State{model: model} = state) do
    {state.focused, state.focused_field, model.status, model.error, model.case_sensitive,
     model.regex}
  end

  # The rows are derived from a good deal of state — results, dismissals, which
  # scope nodes are open, which file groups are collapsed — so they are
  # compared directly rather than by guessing at their inputs. Building the
  # list is cheap; building its primitives is not, and that is what this
  # avoids.
  defp body_changed?(old_state, new_state) do
    old_state.hovered != new_state.hovered or
      old_state.scroll != new_state.scroll or
      State.rows(old_state) != State.rows(new_state)
  end

  @doc "Move the already-rendered body to a new scroll offset."
  def scroll_to(graph, %State{} = old_state, %State{} = new_state) do
    graph
    |> update_scroll_transform(:search_pane_scroll, old_state.scroll, new_state.scroll)
    |> update_scrollbars(
      old_state.scroll,
      new_state.scroll,
      State.body_frame(new_state),
      color: new_state.theme.scrollbar_color,
      group_id: :search_pane
    )
  end

  # ── Header ────────────────────────────────────────────────────────────────

  # The parts that change while the pane is being used, and that this module
  # draws itself. The two editable fields are NOT among them: they are
  # TextField components (see render_fields/2), created once and updated by
  # message, never redrawn from here.
  defp render_widgets(graph, %State{} = state) do
    live =
      State.header_widgets(state)
      |> Enum.reject(&(&1.id == :close))
      |> Enum.reject(&match?(%{id: {:field, _}}, &1))

    Primitives.group(
      graph,
      fn g -> Enum.reduce(live, g, &render_header_widget(&2, &1, state)) end,
      id: :search_pane_widgets,
      translate: {0, 0}
    )
  end

  @doc """
  The editable fields, as real TextFields.

  Called once, from `render/1`. Everything a one-line input should do —
  selection, the clipboard, word-wise movement, Ctrl+Backspace — is behaviour
  this pane used to reimplement, badly and partially, and now simply gets. The
  cost is that they are processes: they have to survive every redraw, which is
  why the rest of this module is written the way it is.
  """
  def render_fields(graph, %State{} = state) do
    State.header_widgets(state)
    |> Enum.filter(&match?(%{id: {:field, _}}, &1))
    |> Enum.reduce(graph, fn %{id: {:field, field}} = w, g ->
      # TRANSLATE, not a pinned frame. A TextField draws from its own origin
      # and hit-tests against 0..width (State.point_inside?/2), so a frame
      # pinned where the field belongs draws it in the right place by accident
      # while testing every click in the wrong space — clicks near its right
      # edge fall outside and blur it.
      ScenicWidgets.TextField.add_to_graph(g, field_data(w, field, state),
        id: field_id(field),
        translate: {w.x, w.y}
      )
    end)
  end

  @doc """
  Where a field is and how it looks — everything it takes from the pane.

  `nil` when that field is not on screen: the replacement row lives behind a
  disclosure, and asking after it while it is shut used to hand a nil
  rectangle to Frame.new and take the pane down with it.
  """
  def field_settings(%State{theme: theme} = state, field) do
    case Enum.find(State.header_widgets(state), &(&1.id == {:field, field})) do
      nil ->
        nil

      w ->
        %{
          frame: Widgex.Frame.new(%{pin: {0, 0}, size: {w.w, w.h}}),
          colors: field_colors(theme),
          font: field_font(theme),
          placeholder: placeholder(field)
        }
    end
  end

  @doc "Move the field components after a resize."
  def move_fields(graph, %State{} = state) do
    Enum.reduce(State.fields(), graph, fn field, g ->
      w = Enum.find(State.header_widgets(state), &(&1.id == {:field, field}))

      case Graph.get(g, field_id(field)) do
        [] -> g
        _ -> Graph.modify(g, field_id(field), &Scenic.Primitive.put_transform(&1, :translate, {w.x, w.y}))
      end
    end)
  end

  @doc "The component id a field's TextField is registered under."
  def field_id(:query), do: :search_pane_query_field
  def field_id(:replace), do: :search_pane_replace_field

  defp field_data(w, field, %State{theme: theme} = state) do
    %{
      id: field_id(field),
      frame: Widgex.Frame.new(%{pin: {0, 0}, size: {w.w, w.h}}),
      initial_text: State.field_value(state, field),
      # A pane opened on a seeded query shows it selected. The seed arrives as
      # part of the pane's own construction, before there is a field to send
      # it to, so it has to be part of how the field starts.
      initial_selection: if(field == :query and state.query != "", do: :all, else: nil),
      mode: :single_line,
      input_mode: :direct,
      show_line_numbers: false,
      placeholder: placeholder(field),
      focused: state.focused and state.focused_field == field,
      editable: true,
      colors: field_colors(theme),
      font: field_font(theme)
    }
  end

  # A TextField measures text, so it needs real metrics rather than a font
  # name. The theme names a font the host has registered as a static asset,
  # which is where the metrics live; if it has not, that is a mistake worth
  # hearing about rather than a reason to draw with the wrong widths.
  defp field_font(theme) do
    {:ok, {Scenic.Assets.Static.Font, metrics}} = Scenic.Assets.Static.meta(theme.font)
    %{name: theme.font, size: theme.font_size, metrics: metrics}
  end

  # The field draws its own backdrop and border now. The pane used to draw a
  # rect underneath it and repaint the border on every focus change.
  defp field_colors(theme) do
    %{
      text: theme.text,
      placeholder: theme.dim_text,
      background: theme.field_background,
      border: theme.field_border,
      focused_border: theme.field_focus_border,
      cursor: theme.field_focus_border,
      # Selection is drawn OVER the text, so it has to be translucent — and
      # Scenic wants that said explicitly: a three-part colour here is not a
      # colour it will accept.
      selection: with_alpha(theme.match_highlight, 160)
    }
  end

  defp with_alpha({r, g, b}, a), do: {r, g, b, a}
  defp with_alpha({r, g, b, _a}, a), do: {r, g, b, a}

  defp render_header_widget(graph, %{id: {:toggle, option}} = w, %State{theme: theme} = state) do
    on? = Map.fetch!(state.model, option)
    label = if option == :case_sensitive, do: "Aa", else: ".*"

    graph
    |> Primitives.rect({w.w, w.h},
      fill: if(on?, do: theme.button_active, else: theme.button_background),
      stroke: {1, theme.field_border},
      translate: {w.x, w.y}
    )
    |> Primitives.text(label,
      translate: {w.x + w.w / 2, w.y + w.h - 7},
      text_align: :center,
      fill: theme.button_text,
      font: theme.font,
      font_size: theme.small_font_size
    )
  end

  # The disclosure for the replacement row — a triangle pointing at what it
  # opens, the same idiom as the find bar's.
  defp render_header_widget(graph, %{id: :replace_caret} = w, %State{theme: theme} = state) do
    cx = w.x + w.w / 2
    cy = w.y + theme.field_height / 2
    r = 4

    points =
      if state.replace_open?,
        do: {{cx - r, cy - r / 2}, {cx + r, cy - r / 2}, {cx, cy + r}},
        else: {{cx - r / 2, cy - r}, {cx + r, cy}, {cx - r / 2, cy + r}}

    Primitives.triangle(graph, points, fill: theme.dim_text, id: :replace_disclosure)
  end

  # Replace All: an arrow going into a stack of lines, the same glyph the find
  # bar uses for it. Two spellings of one action in one editor is one too many.
  defp render_header_widget(graph, %{id: :replace_all} = w, %State{theme: theme}) do
    cx = w.x + w.w / 2
    cy = w.y + w.h / 2
    arrow_y = cy - 5

    graph
    |> Primitives.rounded_rectangle({w.w, w.h, 3},
      fill: theme.button_background,
      stroke: {1, theme.field_border},
      translate: {w.x, w.y}
    )
    |> Primitives.line({{cx - 6, arrow_y}, {cx + 3, arrow_y}},
      stroke: {1.5, theme.button_text},
      cap: :round
    )
    |> Primitives.line({{cx, arrow_y - 3}, {cx + 3, arrow_y}},
      stroke: {1.5, theme.button_text},
      cap: :round
    )
    |> Primitives.line({{cx, arrow_y + 3}, {cx + 3, arrow_y}},
      stroke: {1.5, theme.button_text},
      cap: :round
    )
    |> then(fn g ->
      Enum.reduce(0..2, g, fn i, acc ->
        y = cy + 2 + i * 3

        Primitives.line(acc, {{cx - 6, y}, {cx + 6, y}},
          stroke: {1.3, theme.button_text},
          cap: :round
        )
      end)
    end)
  end

  # The disclosure for the search domain: a caret and a word, not three dots.
  # A control that hides something should say what it is hiding.
  defp render_header_widget(graph, %{id: :domain_header} = w, %State{theme: theme} = state) do
    label = if state.domain_open?, do: "▾ SEARCH DOMAIN", else: "▸ SEARCH DOMAIN"

    Primitives.text(graph, label,
      id: :domain_header_text,
      translate: {w.x, w.y + w.h - 6},
      fill: theme.heading,
      font: theme.font,
      font_size: theme.small_font_size
    )
  end

  # A domain option, drawn as a tick box and a sentence — these are choices
  # about where to look, and a two-letter glyph could not say which is which.
  defp render_header_widget(graph, %{id: {:domain, option}} = w, %State{theme: theme} = state) do
    on? = Map.fetch!(state.model, option)
    mark = if on?, do: "[x]", else: "[ ]"

    Primitives.text(graph, mark <> "  " <> domain_label(option),
      translate: {w.x + 2, w.y + w.h - 6},
      fill: if(on?, do: theme.text, else: theme.dim_text),
      font: theme.font,
      font_size: theme.small_font_size
    )
  end

  defp domain_label(:open_buffers_only), do: "Search only open buffers"
  defp domain_label(:use_ignore_files), do: "Use exclude settings & ignore files"

  defp render_header_widget(graph, %{id: :status} = w, %State{theme: theme} = state) do
    {text, colour} = status_line(state)

    Primitives.text(graph, text,
      translate: {w.x, w.y + w.h - 6},
      fill: colour,
      font: theme.font,
      font_size: theme.small_font_size
    )
  end

  defp placeholder(:query), do: "Search project"
  defp placeholder(:replace), do: "Replace with"

  defp status_line(%State{model: %{error: error}, theme: theme}) when is_binary(error),
    do: {error, theme.error_text}

  defp status_line(%State{model: model, theme: theme}) do
    text =
      case model.status do
        :idle -> "Type to search the project"
        :searching -> "searching…"
        {:done, 0, 0, _ms} -> "no matches"
        {:done, n, files, ms} -> "#{n} in #{files} #{plural(files, "file")}  (#{ms}ms)"
        {:error, reason} -> "search failed: #{inspect(reason)}"
      end

    colour = if match?({:error, _}, model.status), do: theme.error_text, else: theme.dim_text
    {text, colour}
  end

  defp plural(1, word), do: word
  defp plural(_n, word), do: word <> "s"

  # ── Body ──────────────────────────────────────────────────────────────────

  defp render_body(graph, %State{theme: theme} = state) do
    body = State.body_frame(state)
    rows = State.rows(state)

    Primitives.group(
      graph,
      fn g ->
        g
        |> scrollable_group(
          state.scroll,
          body,
          fn sg -> Enum.reduce(rows, sg, &render_row(&2, &1, state)) end,
          id: :search_pane_scroll,
          overlay_scrollbars: true
        )
        |> render_scrollbars(state.scroll, body,
          color: theme.scrollbar_color,
          group_id: :search_pane
        )
      end,
      id: :search_pane_body,
      translate: {0, State.header_height(state)}
    )
  end

  defp render_row(graph, row, %State{theme: theme} = state) do
    hovered? = state.hovered == row.id
    x = theme.padding + row.depth * theme.indent
    room = state.frame.size.width - x - 60
    label = clip(row.label, room, theme.font_size)

    Primitives.group(
      graph,
      fn g ->
        g
        |> row_background(row, hovered?, state)
        |> maybe_match_highlight(row, x, String.length(label), theme)
        |> Primitives.text(label,
          translate: {x, row.height - 6},
          fill: row_colour(row, theme),
          font: theme.font,
          font_size: row_font_size(row, theme)
        )
        |> render_actions(row, hovered?, state)
      end,
      translate: {0, row.y}
    )
  end

  defp row_background(graph, _row, false, _state), do: graph

  defp row_background(graph, row, true, %State{theme: theme, frame: frame}) do
    Primitives.rect(graph, {frame.size.width, row.height},
      fill: theme.row_hover,
      id: {:row_hover, row.id}
    )
  end

  # The whole point of drawing matches in a pane of their own: the matched text
  # is marked inside the line, so a result reads as a hit rather than as a line
  # that happens to be listed.
  defp maybe_match_highlight(graph, %{kind: :match} = row, x, drawn_chars, theme) do
    # The row's text is clipped to the pane's width, so the highlight has to be
    # clipped with it. Drawing the full match regardless left a stray block
    # floating past the end of a truncated line, marking nothing.
    visible = min(row.match_len, drawn_chars - row.match_start)

    if visible > 0 do
      cw = char_width(theme.font_size)

      Primitives.rect(graph, {visible * cw, theme.font_size + 2},
        fill: theme.match_highlight,
        translate: {x + row.match_start * cw, @highlight_top}
      )
    else
      graph
    end
  end

  defp maybe_match_highlight(graph, _row, _x, _drawn_chars, _theme), do: graph

  defp row_colour(%{kind: :file}, theme), do: theme.text
  defp row_colour(%{kind: :scope_header}, theme), do: theme.heading
  defp row_colour(%{kind: :scope}, theme), do: theme.dim_text
  defp row_colour(_row, theme), do: theme.dim_text

  defp row_font_size(%{kind: :scope_header}, theme), do: theme.small_font_size
  defp row_font_size(_row, theme), do: theme.font_size

  defp render_actions(graph, _row, false, _state), do: graph

  defp render_actions(graph, row, true, %State{theme: theme} = state) do
    Enum.reduce(State.action_bounds(state, row), graph, fn b, g ->
      g
      |> Primitives.rect({b.w, b.h},
        fill: theme.button_background,
        translate: {b.x, b.y - row.y}
      )
      |> Primitives.text(action_glyph(b.action),
        translate: {b.x + b.w / 2, b.y - row.y + b.h - 4},
        text_align: :center,
        fill: theme.button_text,
        font: theme.font,
        font_size: theme.small_font_size
      )
    end)
  end

  defp action_glyph({:replace_file, _}), do: "↺"
  defp action_glyph({:replace_match, _, _, _}), do: "↺"
  defp action_glyph({:dismiss_file, _}), do: "×"
  defp action_glyph({:dismiss_match, _, _, _}), do: "×"

  # ── Text metrics ──────────────────────────────────────────────────────────
  #
  # The pane is monospaced, so a ratio beats a metrics lookup — the same
  # approximation TabBar uses for its labels.

  defp char_width(font_size), do: font_size * 0.6

  defp max_chars(width, font_size), do: max(trunc(width / char_width(font_size)), 0)

  defp clip(text, width, font_size) do
    limit = max_chars(width, font_size)

    if String.length(text) <= limit,
      do: text,
      else: String.slice(text, 0, max(limit - 1, 0)) <> "…"
  end
end
