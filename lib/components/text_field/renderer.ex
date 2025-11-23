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
    |> render_selection(state)
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

  defp render_selection(graph, %State{selection: nil}), do: graph

  defp render_selection(graph, %State{
    selection: {start_pos, end_pos},
    lines: lines,
    font: font
  } = state) do
    # Normalize selection - ensure start comes before end
    {{sel_start_line, sel_start_col}, {sel_end_line, sel_end_col}} =
      if start_pos <= end_pos do
        {start_pos, end_pos}
      else
        {end_pos, start_pos}
      end

    # Skip if selection is empty (start == end)
    if sel_start_line == sel_end_line and sel_start_col == sel_end_col do
      graph
    else
      render_selection_rectangles(
        graph,
        {sel_start_line, sel_start_col},
        {sel_end_line, sel_end_col},
        lines,
        font,
        state
      )
    end
  end

  defp render_selection_rectangles(graph, {sel_start_line, sel_start_col}, {sel_end_line, sel_end_col}, lines, font, state) do
    x_offset = State.text_x_offset(state)
    line_height = font.size
    char_width = trunc(font.size * 0.6)  # Monospace approximation

    # Selection color - semi-transparent blue
    selection_color = {:color_rgba, {100, 150, 200, 100}}

    # Render selection rectangles for each line in the selection
    Enum.reduce(sel_start_line..sel_end_line, graph, fn line_num, acc_graph ->
      y_position = (line_num - 1) * line_height
      line_text = Enum.at(lines, line_num - 1, "")

      # Calculate selection bounds for this line
      {start_col_on_line, end_col_on_line} =
        cond do
          line_num == sel_start_line and line_num == sel_end_line ->
            # Selection within same line
            {sel_start_col, sel_end_col}
          line_num == sel_start_line ->
            # First line of multi-line selection
            {sel_start_col, String.length(line_text) + 1}
          line_num == sel_end_line ->
            # Last line of multi-line selection
            {1, sel_end_col}
          true ->
            # Middle line of multi-line selection
            {1, String.length(line_text) + 1}
        end

      # Calculate pixel coordinates for selection rectangle
      start_x_offset = (start_col_on_line - 1) * char_width
      selection_length = max(0, end_col_on_line - start_col_on_line)
      selection_width = selection_length * char_width

      # Add selection rectangle to graph
      acc_graph
      |> Primitives.rect(
        {selection_width, line_height},
        fill: selection_color,
        translate: {x_offset + start_x_offset, y_position},
        id: {:selection_highlight, line_num}
      )
    end)
  end

  defp render_lines(graph, %State{
    lines: lines,
    font: font,
    colors: colors,
    wrap_mode: wrap_mode,
    frame: frame,
    show_line_numbers: show_line_numbers,
    line_number_width: line_number_width
  } = state) do
    x_offset = State.text_x_offset(state)

    # Calculate available width for text
    text_width = if show_line_numbers do
      frame.size.width - line_number_width - 20  # Account for margins
    else
      frame.size.width - 20  # 10px padding on each side
    end

    # Wrap lines if needed
    display_lines = if wrap_mode == :word do
      lines
      |> Enum.flat_map(&wrap_line(&1, text_width, font))
    else
      lines
    end

    # Render each display line
    Enum.reduce(Enum.with_index(display_lines, 1), graph, fn {line_text, display_line_num}, g ->
      y_pos = (display_line_num - 1) * font.size + font.size

      g
      |> Primitives.text(
        line_text,
        translate: {x_offset, y_pos},
        fill: colors.text,
        font_size: font.size,
        font: font.name,
        id: {:text_line, display_line_num}
      )
    end)
  end

  # Wrap a single line into multiple lines based on available width
  defp wrap_line(line, max_width, font) do
    # Approximate character width (monospace)
    char_width = font.size * 0.6
    max_chars = trunc(max_width / char_width)

    if String.length(line) <= max_chars do
      [line]
    else
      wrap_line_by_words(line, max_chars)
    end
  end

  # Word-based wrapping
  defp wrap_line_by_words(line, max_chars) do
    words = String.split(line, " ")

    words
    |> Enum.reduce({[], ""}, fn word, {wrapped_lines, current_line} ->
      test_line = if current_line == "", do: word, else: current_line <> " " <> word

      if String.length(test_line) <= max_chars do
        # Word fits on current line
        {wrapped_lines, test_line}
      else
        # Word doesn't fit, start new line
        if current_line == "" do
          # Single word exceeds line - just add it anyway
          {wrapped_lines ++ [word], ""}
        else
          # Move to next line
          {wrapped_lines ++ [current_line], word}
        end
      end
    end)
    |> then(fn {wrapped_lines, current_line} ->
      if current_line == "", do: wrapped_lines, else: wrapped_lines ++ [current_line]
    end)
  end

  defp render_cursor(graph, %State{
    cursor: {line, col},
    cursor_visible: visible,
    focused: focused,
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
    # Only show when focused AND visible (for blinking)
    graph
    |> Primitives.rect(
      {2, font.size},
      translate: {cursor_x, cursor_y},
      fill: colors.cursor,
      hidden: !focused or !visible,
      id: :cursor
    )
  end
end
