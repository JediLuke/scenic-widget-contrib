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
  Update render - intelligently updates only what changed.
  """
  def update_render(graph, old_state, new_state) do
    graph
    |> update_border_if_changed(old_state, new_state)
    |> update_lines_if_changed(old_state, new_state)
    |> update_line_numbers_if_changed(old_state, new_state)
    |> update_cursor_position(old_state, new_state)
  end

  defp update_border_if_changed(graph, %State{focused: old_focused}, %State{focused: new_focused, colors: colors})
      when old_focused != new_focused do
    border_color = if new_focused, do: colors.focused_border, else: colors.border

    graph
    |> Graph.modify(:border, fn primitive ->
      Primitives.update_opts(primitive, stroke: {1, border_color})
    end)
  end

  defp update_border_if_changed(graph, _old_state, _new_state), do: graph

  defp update_lines_if_changed(graph, %State{lines: old_lines}, %State{lines: new_lines} = new_state)
      when old_lines != new_lines do
    # Lines changed - update text rendering
    # For simplicity, re-render all lines if any changed
    # TODO: Optimize to only update changed lines
    x_offset = State.text_x_offset(new_state)
    font = new_state.font
    colors = new_state.colors

    # Remove old line primitives and add new ones
    graph = Enum.reduce(1..length(old_lines), graph, fn line_num, g ->
      Graph.delete(g, {:text_line, line_num})
    end)

    # Add new lines
    Enum.reduce(Enum.with_index(new_lines, 1), graph, fn {line_text, line_num}, g ->
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

  defp update_lines_if_changed(graph, _old_state, _new_state), do: graph

  defp update_line_numbers_if_changed(graph, %State{lines: old_lines, show_line_numbers: true},
                                       %State{lines: new_lines, show_line_numbers: true} = new_state)
      when length(old_lines) != length(new_lines) do
    # Line count changed - update line numbers
    # Remove old line numbers
    graph = Enum.reduce(1..length(old_lines), graph, fn line_num, g ->
      Graph.delete(g, {:line_number, line_num})
    end)

    # Add new line numbers
    width = new_state.line_number_width
    font = new_state.font
    colors = new_state.colors

    Enum.reduce(1..length(new_lines), graph, fn line_num, g ->
      y_pos = (line_num - 1) * font.size + font.size
      x_pos = width - 10

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

  defp update_line_numbers_if_changed(graph, _old_state, _new_state), do: graph

  defp update_cursor_position(graph, %State{cursor: old_cursor}, %State{cursor: new_cursor} = new_state)
      when old_cursor != new_cursor do
    {line, col} = new_cursor
    x_offset = State.text_x_offset(new_state)
    font = new_state.font

    # Calculate cursor position
    char_width = trunc(font.size * 0.6)
    cursor_x = x_offset + ((col - 1) * char_width)
    cursor_y = (line - 1) * font.size

    # Only show cursor if focused AND cursor_visible (for blinking)
    should_show_cursor = new_state.focused and new_state.cursor_visible

    graph
    |> Graph.modify(:cursor, fn primitive ->
      Primitives.update_opts(primitive, translate: {cursor_x, cursor_y}, hidden: !should_show_cursor)
    end)
  end

  defp update_cursor_position(graph, _old_state, _new_state), do: graph

  @doc """
  Quick update for cursor visibility (blink animation).
  Only updates cursor visibility without re-rendering everything.
  """
  def update_cursor_visibility(graph, %State{focused: focused, cursor_visible: cursor_visible} = state) do
    # Only show cursor if focused AND cursor_visible (for blinking)
    should_show_cursor = focused and cursor_visible

    graph
    |> Graph.modify(:cursor, fn primitive ->
      Primitives.update_opts(primitive, hidden: !should_show_cursor)
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
