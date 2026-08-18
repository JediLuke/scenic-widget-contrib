defmodule ScenicWidgets.SearchPane.Renderizer do
  @moduledoc """
  Draws `ScenicWidgets.SearchPane`.

  The pane is rebuilt from scratch on every change. Its content is bounded by
  what fits in a sidebar, so there is nothing here worth the bookkeeping of an
  incremental update — except the scroll transform, which moves on every wheel
  tick and is handled by `Widgex.Scrollable`.
  """

  use Widgex.Scrollable, direction: :vertical

  alias Scenic.Graph
  alias Scenic.Primitives
  alias ScenicWidgets.SearchPane.State

  # Where a match's highlight rectangle sits relative to the text baseline.
  @highlight_top 3

  def render(%State{} = state) do
    Graph.build()
    |> Primitives.group(
      fn g ->
        g
        |> Primitives.rect(state.frame.size.box,
          id: :search_pane_background,
          fill: state.theme.background,
          stroke: {1, state.theme.border},
          input: [:cursor_button, :cursor_pos]
        )
        |> render_body(state)
        |> render_header(state)
      end,
      translate: {0, 0}
    )
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

  defp render_header(graph, %State{theme: theme} = state) do
    height = State.header_height(state)

    graph
    |> Primitives.group(
      fn g ->
        g
        |> Primitives.rect({state.frame.size.width, height}, fill: theme.header_background)
        |> Primitives.line({{0, height}, {state.frame.size.width, height}},
          stroke: {1, theme.border}
        )
        |> Primitives.text("SEARCH",
          translate: {theme.padding, theme.padding + theme.row_height - 6},
          fill: theme.heading,
          font: theme.font,
          font_size: theme.small_font_size
        )
        |> render_header_widgets(state)
      end,
      id: :search_pane_header,
      translate: {0, 0}
    )
  end

  defp render_header_widgets(graph, state) do
    Enum.reduce(State.header_widgets(state), graph, &render_header_widget(&2, &1, state))
  end

  defp render_header_widget(graph, %{id: :close} = w, %State{theme: theme}) do
    Primitives.text(graph, "×",
      translate: {w.x + 4, w.y + w.h - 6},
      fill: theme.dim_text,
      font: theme.font,
      font_size: theme.font_size
    )
  end

  defp render_header_widget(graph, %{id: {:field, field}} = w, %State{theme: theme} = state) do
    focused? = state.focused and state.focused_field == field
    value = State.field_value(state, field)
    stroke = if focused?, do: theme.field_focus_border, else: theme.field_border

    graph
    |> Primitives.rect({w.w, w.h},
      fill: theme.field_background,
      stroke: {1, stroke},
      translate: {w.x, w.y}
    )
    |> field_text(w, value, field, theme)
    |> maybe_caret(w, value, focused?, state, field)
  end

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

  defp render_header_widget(graph, %{id: :replace_all} = w, %State{theme: theme}) do
    graph
    |> Primitives.rect({w.w, w.h},
      fill: theme.button_background,
      stroke: {1, theme.field_border},
      translate: {w.x, w.y}
    )
    |> Primitives.text("All",
      translate: {w.x + w.w / 2, w.y + w.h - 7},
      text_align: :center,
      fill: theme.button_text,
      font: theme.font,
      font_size: theme.small_font_size
    )
  end

  defp render_header_widget(graph, %{id: :status} = w, %State{theme: theme} = state) do
    {text, colour} = status_line(state)

    Primitives.text(graph, text,
      translate: {w.x, w.y + w.h - 6},
      fill: colour,
      font: theme.font,
      font_size: theme.small_font_size
    )
  end

  defp field_text(graph, w, "", field, theme) do
    Primitives.text(graph, placeholder(field),
      translate: {w.x + 5, w.y + w.h - 7},
      fill: theme.dim_text,
      font: theme.font,
      font_size: theme.font_size
    )
  end

  defp field_text(graph, w, value, _field, theme) do
    Primitives.text(graph, clip(value, w.w - 10, theme.font_size),
      translate: {w.x + 5, w.y + w.h - 7},
      fill: theme.text,
      font: theme.font,
      font_size: theme.font_size
    )
  end

  defp placeholder(:query), do: "Search project"
  defp placeholder(:replace), do: "Replace with"

  defp maybe_caret(graph, _w, _value, false, _state, _field), do: graph

  defp maybe_caret(graph, w, _value, true, state, field) do
    theme = state.theme
    cursor = Map.fetch!(state.cursors, field)
    visible = min(cursor, max_chars(w.w - 10, theme.font_size))
    x = w.x + 5 + visible * char_width(theme.font_size)

    Primitives.line(graph, {{x, w.y + 4}, {x, w.y + w.h - 4}},
      stroke: {1, theme.field_focus_border}
    )
  end

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
