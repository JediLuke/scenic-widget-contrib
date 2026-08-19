defmodule ScenicWidgets.SearchBar.Renderer do
  @moduledoc """
  Draws `ScenicWidgets.SearchBar`.

  The arrangement is the one every editor has settled on, and for reasons
  worth writing down:

      [⌄] [ Find……………………………… Aa .* ] [‹] [3/10] [›]              [×]
          [ Replace………………………………… ]                     [→] [⇉]

  * The **disclosure caret** is on the far left, where something that opens
    another row belongs — it points at what it opens.
  * The **close** is on the far right. It used to be on the left, in the
    caret's place, which put the most destructive control in the bar under
    the pointer's resting position.
  * The **option toggles** sit inside the right-hand end of the field they
    apply to, so it reads that they modify the query rather than the search.
  * Every button has a tooltip. These are drawn glyphs rather than words, and
    an icon that cannot say what it does has to be guessed at.

  Every rectangle here comes from `State.widgets/1` — the same list the hit
  test uses, so a button cannot draw in one place and respond in another.
  """

  alias ScenicWidgets.SearchBar.State
  alias ScenicWidgets.{FloatingPanel, Tooltip}
  alias Scenic.Graph
  alias Scenic.Primitives

  # Text inset inside both input fields
  @text_inset 8

  @doc "Layout constants shared with the component's hit-testing."
  defdelegate button_width(), to: State
  defdelegate match_count_width(), to: State

  @doc "The complete search bar, replace row and all."
  def render(%State{} = state) do
    width = State.frame_width(state)
    widgets = State.widgets(state)

    Graph.build()
    |> FloatingPanel.add_card({width, State.height(state)},
      id: :search_bar_bg,
      fill: state.theme.background,
      border: state.theme.border
    )
    |> render_widgets(widgets, state)
    |> Tooltip.add(tooltip_for(state.hovered, widgets), state.theme, width)
  end

  defp tooltip_for(nil, _widgets), do: nil

  defp tooltip_for(id, widgets) do
    case Enum.find(widgets, &(&1.id == id and &1.tooltip != nil)) do
      nil -> nil
      w -> %{text: w.tooltip, at: {w.x, w.y + w.h}}
    end
  end

  defp render_widgets(graph, widgets, state) do
    Enum.reduce(widgets, graph, &render_widget(&2, &1, state))
  end

  # ── The widgets ───────────────────────────────────────────────────────────

  defp render_widget(graph, %{id: :toggle_replace} = w, %State{} = state) do
    graph
    |> hover_backdrop(w, state)
    |> caret(w, state.replace_mode, state.theme.text)
  end

  defp render_widget(graph, %{id: :search_field} = w, %State{} = state) do
    focused? = state.focused and state.focused_field == :search
    text = if state.query == "", do: "Find", else: state.query
    colour = if state.query == "", do: state.theme.placeholder, else: state.theme.text

    graph
    |> input_box(w, focused?, state.theme)
    |> Primitives.text(text,
      id: :query_text,
      font: state.font.name,
      font_size: state.font.size,
      fill: colour,
      translate: {w.x + @text_inset, w.y + w.h / 2 + 5}
    )
    |> caret_line(focused?, w, cursor_x(state.cursor_pos, state.font), :cursor, state.theme)
  end

  defp render_widget(graph, %{id: :replace_field} = w, %State{} = state) do
    focused? = state.focused and state.focused_field == :replace
    text = if state.replace_query == "", do: "Replace", else: state.replace_query
    colour = if state.replace_query == "", do: state.theme.placeholder, else: state.theme.text

    graph
    |> input_box(w, focused?, state.theme)
    |> Primitives.text(text,
      id: :replace_text,
      font: state.font.name,
      font_size: state.font.size,
      fill: colour,
      translate: {w.x + @text_inset, w.y + w.h / 2 + 5}
    )
    |> caret_line(
      focused?,
      w,
      cursor_x(state.replace_cursor_pos, state.font),
      :replace_cursor,
      state.theme
    )
  end

  defp render_widget(graph, %{id: {:toggle, option}} = w, %State{} = state) do
    on? = Map.fetch!(state, option)
    label = if option == :case_sensitive, do: "Aa", else: ".*"

    graph
    |> Primitives.rounded_rectangle({w.w, w.h, 3},
      id: {:option, option},
      fill: if(on?, do: state.theme.option_on, else: :clear),
      stroke: {1, if(on?, do: state.theme.option_on_border, else: state.theme.background)},
      translate: {w.x, w.y}
    )
    |> Primitives.text(label,
      font: :roboto_mono,
      font_size: 12,
      fill: if(on?, do: state.theme.text, else: state.theme.placeholder),
      text_align: :center,
      translate: {w.x + w.w / 2, w.y + w.h / 2 + 4}
    )
  end

  defp render_widget(graph, %{id: :prev} = w, %State{} = state) do
    graph |> hover_backdrop(w, state) |> chevron(w, :left, state.theme.text)
  end

  defp render_widget(graph, %{id: :next} = w, %State{} = state) do
    graph |> hover_backdrop(w, state) |> chevron(w, :right, state.theme.text)
  end

  defp render_widget(graph, %{id: :count} = w, %State{} = state) do
    text =
      if state.total_matches > 0,
        do: "#{state.current_match}/#{state.total_matches}",
        else: "0/0"

    colour =
      if state.total_matches > 0, do: state.theme.match_highlight, else: state.theme.placeholder

    Primitives.text(graph, text,
      id: :match_count,
      font: :roboto_mono,
      font_size: 14,
      fill: colour,
      text_align: :center,
      translate: {w.x + w.w / 2, w.y + w.h / 2 + 5}
    )
  end

  defp render_widget(graph, %{id: :close} = w, %State{} = state) do
    graph |> hover_backdrop(w, state) |> cross(w, state.theme.text)
  end

  defp render_widget(graph, %{id: :replace_one} = w, %State{} = state) do
    graph |> hover_backdrop(w, state) |> replace_icon(w, 1, state.theme.text)
  end

  defp render_widget(graph, %{id: :replace_all} = w, %State{} = state) do
    graph |> hover_backdrop(w, state) |> replace_icon(w, 3, state.theme.text)
  end

  # ── Pieces ────────────────────────────────────────────────────────────────

  # Buttons are transparent until the pointer is on them. A row of filled
  # rectangles reads as a toolbar of its own, and competes with the field —
  # which is the thing the bar is actually about.
  defp hover_backdrop(graph, %{id: id} = w, %State{hovered: id, theme: theme}) do
    Primitives.rounded_rectangle(graph, {w.w - 4, w.h - 8, 4},
      fill: theme.button_hover,
      translate: {w.x + 2, w.y + 4}
    )
  end

  defp hover_backdrop(graph, _w, _state), do: graph

  defp input_box(graph, w, focused?, theme) do
    Primitives.rounded_rectangle(graph, {w.w, w.h, 4},
      fill: theme.input_background,
      stroke: {1, if(focused?, do: theme.focus_border, else: theme.border)},
      translate: {w.x, w.y}
    )
  end

  defp cursor_x(0, _font), do: 0
  defp cursor_x(pos, font), do: pos * font.size * 0.6

  defp caret_line(graph, false, _w, _offset, _id, _theme), do: graph

  defp caret_line(graph, true, w, offset, id, theme) do
    x = w.x + @text_inset + offset

    Primitives.line(graph, {{x, w.y + 4}, {x, w.y + w.h - 4}}, id: id, stroke: {2, theme.text})
  end

  # A disclosure triangle: pointing right when the replace row is hidden, down
  # when it is showing. It points AT what it opens.
  defp caret(graph, w, open?, colour) do
    cx = w.x + w.w / 2
    cy = w.y + w.h / 2
    r = 4

    points =
      if open?,
        do: {{cx - r, cy - r / 2}, {cx + r, cy - r / 2}, {cx, cy + r}},
        else: {{cx - r / 2, cy - r}, {cx + r, cy}, {cx - r / 2, cy + r}}

    Primitives.triangle(graph, points, fill: colour, id: :replace_caret)
  end

  defp chevron(graph, w, direction, colour) do
    cx = w.x + w.w / 2
    cy = w.y + w.h / 2
    dx = if direction == :left, do: 4, else: -4

    graph
    |> Primitives.line({{cx + dx, cy - 5}, {cx - dx, cy}}, stroke: {2, colour}, cap: :round)
    |> Primitives.line({{cx - dx, cy}, {cx + dx, cy + 5}}, stroke: {2, colour}, cap: :round)
  end

  defp cross(graph, w, colour) do
    cx = w.x + w.w / 2
    cy = w.y + w.h / 2
    r = 5

    graph
    |> Primitives.line({{cx - r, cy - r}, {cx + r, cy + r}}, stroke: {2, colour}, cap: :round)
    |> Primitives.line({{cx + r, cy - r}, {cx - r, cy + r}}, stroke: {2, colour}, cap: :round)
  end

  # An arrow going INTO lines: one line for "replace this one", a stack of
  # them for "replace all of them". The count is the whole difference between
  # the two buttons, so it is the whole difference between the two icons.
  defp replace_icon(graph, w, lines, colour) do
    cx = w.x + w.w / 2
    cy = w.y + w.h / 2
    arrow_y = cy - 5

    graph
    |> Primitives.line({{cx - 7, arrow_y}, {cx + 4, arrow_y}}, stroke: {1.6, colour}, cap: :round)
    |> Primitives.line({{cx + 1, arrow_y - 3}, {cx + 4, arrow_y}}, stroke: {1.6, colour}, cap: :round)
    |> Primitives.line({{cx + 1, arrow_y + 3}, {cx + 4, arrow_y}}, stroke: {1.6, colour}, cap: :round)
    |> then(fn g ->
      Enum.reduce(0..(lines - 1), g, fn i, acc ->
        y = cy + 2 + i * 3.5

        Primitives.line(acc, {{cx - 7, y}, {cx + 7, y}}, stroke: {1.4, colour}, cap: :round)
      end)
    end)
  end

  @doc "Updates the match count display."
  def update_match_count(graph, %State{current_match: current, total_matches: total, theme: theme}) do
    text = if total > 0, do: "#{current}/#{total}", else: "0/0"
    colour = if total > 0, do: theme.match_highlight, else: theme.placeholder

    Graph.modify(graph, :match_count, fn primitive ->
      Primitives.text(primitive, text, fill: colour)
    end)
  end
end
