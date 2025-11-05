defmodule ScenicWidgets.TextField.Renderer do
  @moduledoc """
  Rendering logic for the TextField component.

  Phase 1: Basic rendering - background, lines, cursor
  Phase 2+: Incremental updates, scrolling, wrapping
  """

  alias Scenic.Graph
  alias Scenic.Primitives
  alias ScenicWidgets.TextField.State

  @doc """
  Initial render of the TextField component.

  Creates the complete graph structure:
  - Background (optional - supports :clear for transparent)
  - Border
  - Line numbers (if enabled)
  - Text lines
  - Cursor
  """
  def initial_render(graph, %State{} = state) do
    graph
    |> render_background(state)
    |> render_border(state)
    |> render_line_numbers(state)
    |> render_lines(state)
    |> render_cursor(state)
  end

  @doc """
  Update render - for now, just re-renders everything.
  Phase 2+ will implement incremental updates.
  """
  def update_render(graph, _old_state, new_state) do
    # For Phase 1, just rebuild the whole thing
    # TODO Phase 2: Implement incremental updates
    Graph.build()
    |> initial_render(new_state)
  end

  @doc """
  Quick update for cursor visibility (blink animation).
  Only updates cursor visibility without re-rendering everything.
  """
  def update_cursor_visibility(graph, %State{} = state) do
    graph
    |> Graph.modify(:cursor, fn primitive ->
      Primitives.update_opts(primitive, hidden: !state.cursor_visible)
    end)
  end

  # ===== PRIVATE RENDERING FUNCTIONS =====

  defp render_background(graph, %State{colors: %{background: :clear}}) do
    # Transparent background - don't render anything
    graph
  end

  defp render_background(graph, %State{frame: frame, colors: colors}) do
    graph
    |> Primitives.rect(
      {frame.size.width, frame.size.height},
      fill: colors.background,
      id: :background
    )
  end

  defp render_border(graph, %State{frame: frame, colors: colors, focused: focused}) do
    border_color = if focused, do: colors.focused_border, else: colors.border

    graph
    |> Primitives.rect(
      {frame.size.width, frame.size.height},
      stroke: {1, border_color},
      id: :border
    )
  end

  defp render_line_numbers(graph, %State{show_line_numbers: false}), do: graph

  defp render_line_numbers(graph, %State{
    show_line_numbers: true,
    lines: lines,
    line_number_width: width,
    font: font,
    colors: colors
  }) do
    # Render line numbers in left margin
    Enum.reduce(Enum.with_index(lines, 1), graph, fn {_line, line_num}, g ->
      y_pos = (line_num - 1) * font.size + font.size
      x_pos = width - 10  # Right-align within the margin

      g
      |> Primitives.text(
        "#{line_num}",
        translate: {x_pos, y_pos},
        fill: colors.line_numbers,
        font_size: font.size,
        text_align: :right,
        id: {:line_number, line_num}
      )
    end)
  end

  defp render_lines(graph, %State{
    lines: lines,
    font: font,
    colors: colors
  } = state) do
    x_offset = State.text_x_offset(state)

    # Render each line of text
    Enum.reduce(Enum.with_index(lines, 1), graph, fn {line_text, line_num}, g ->
      y_pos = (line_num - 1) * font.size + font.size

      g
      |> Primitives.text(
        line_text,
        translate: {x_offset, y_pos},
        fill: colors.text,
        font_size: font.size,
        font: font.name,
        id: {:text_line, line_num}
      )
    end)
  end

  defp render_cursor(graph, %State{
    cursor: {line, col},
    cursor_visible: visible,
    font: font,
    colors: colors
  } = state) do
    x_offset = State.text_x_offset(state)

    # Calculate cursor position
    # TODO Phase 2: Use FontMetrics for accurate character positioning
    # For now, use rough estimate
    char_width = trunc(font.size * 0.6)  # Monospace approximation
    cursor_x = x_offset + ((col - 1) * char_width)
    cursor_y = (line - 1) * font.size

    # Render cursor as thin vertical line
    graph
    |> Primitives.rect(
      {2, font.size},
      translate: {cursor_x, cursor_y},
      fill: colors.cursor,
      hidden: !visible,
      id: :cursor
    )
  end
end
