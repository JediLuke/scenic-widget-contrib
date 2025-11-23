defmodule ScenicWidgets.TextField.Reducer do
  @moduledoc """
  Pure state transition functions for TextField.

  Phase 2: Input handling (process_input/2)
  Phase 3: External actions (process_action/2)

  Returns:
  - {:noop, state} - State changed, no parent notification needed
  - {:event, event_data, state} - State changed, notify parent
  """

  alias ScenicWidgets.TextField.State

  # ===== DIRECT INPUT PROCESSING =====

  @doc """
  Process raw Scenic input events (for direct input mode).
  """
  def process_input(state, input)

  # Mouse click - gain focus
  def process_input(%State{focused: false} = state, {:cursor_button, {:btn_left, 1, _, pos}}) do
    if State.point_inside?(state, pos) do
      {:event, {:focus_gained, state.id}, %{state | focused: true}}
    else
      {:noop, state}
    end
  end

  # Click inside while focused - keep focus (TODO: move cursor to position)
  def process_input(%State{focused: true} = state, {:cursor_button, {:btn_left, 1, _, pos}}) do
    if State.point_inside?(state, pos) do
      {:noop, state}
    else
      {:event, {:focus_lost, state.id}, %{state | focused: false}}
    end
  end

  # Arrow keys - move cursor
  def process_input(%State{focused: true} = state, {:key, {:key_left, 1, _}}) do
    {:noop, move_cursor(state, :left)}
  end

  def process_input(%State{focused: true} = state, {:key, {:key_right, 1, _}}) do
    {:noop, move_cursor(state, :right)}
  end

  def process_input(%State{focused: true} = state, {:key, {:key_up, 1, _}}) do
    {:noop, move_cursor(state, :up)}
  end

  def process_input(%State{focused: true} = state, {:key, {:key_down, 1, _}}) do
    {:noop, move_cursor(state, :down)}
  end

  # Home/End
  def process_input(%State{focused: true} = state, {:key, {:key_home, 1, _}}) do
    {:noop, move_cursor(state, :line_start)}
  end

  def process_input(%State{focused: true} = state, {:key, {:key_end, 1, _}}) do
    {:noop, move_cursor(state, :line_end)}
  end

  # Enter - newline in multi-line, event in single-line
  def process_input(%State{focused: true, mode: :multi_line} = state, {:key, {:key_return, 1, _}}) do
    new_state = insert_newline(state)
    {:event, {:text_changed, state.id, State.get_text(new_state)}, new_state}
  end

  def process_input(%State{focused: true, mode: :single_line} = state, {:key, {:key_return, 1, _}}) do
    {:event, {:enter_pressed, state.id, State.get_text(state)}, state}
  end

  # Backspace
  def process_input(%State{focused: true} = state, {:key, {:key_backspace, 1, _}}) do
    new_state = delete_before_cursor(state)
    {:event, {:text_changed, state.id, State.get_text(new_state)}, new_state}
  end

  # Delete
  def process_input(%State{focused: true} = state, {:key, {:key_delete, 1, _}}) do
    new_state = delete_at_cursor(state)
    {:event, {:text_changed, state.id, State.get_text(new_state)}, new_state}
  end

  # Character input - printable ASCII only for now
  def process_input(%State{focused: true} = state, {:codepoint, {char, _}})
      when char >= 32 and char < 127 do
    new_state = insert_char(state, <<char::utf8>>)
    {:event, {:text_changed, state.id, State.get_text(new_state)}, new_state}
  end

  # Ignore unfocused input
  def process_input(%State{focused: false} = state, _input) do
    {:noop, state}
  end

  # Catch-all for unhandled input
  def process_input(state, _input) do
    {:noop, state}
  end

  # ===== EXTERNAL ACTION PROCESSING (Phase 3) =====

  @doc """
  Process high-level actions (for external control mode).
  Phase 3 implementation.
  """
  def process_action(state, _action) do
    # Phase 3: To be implemented
    {:noop, state}
  end

  # ===== HELPER FUNCTIONS =====

  defp move_cursor(%State{cursor: {line, col}} = state, :left) do
    cond do
      col > 1 ->
        %{state | cursor: {line, col - 1}}

      line > 1 ->
        # Move to end of previous line
        prev_line = State.get_line(state, line - 1)
        %{state | cursor: {line - 1, String.length(prev_line) + 1}}

      true ->
        state
    end
  end

  defp move_cursor(%State{cursor: {line, col}} = state, :right) do
    current_line = State.get_line(state, line)
    line_length = String.length(current_line)

    cond do
      col <= line_length ->
        %{state | cursor: {line, col + 1}}

      line < State.line_count(state) ->
        # Move to start of next line
        %{state | cursor: {line + 1, 1}}

      true ->
        state
    end
  end

  defp move_cursor(%State{cursor: {line, col}} = state, :up) do
    if line > 1 do
      %{state | cursor: {line - 1, col}}
    else
      state
    end
  end

  defp move_cursor(%State{cursor: {line, col}} = state, :down) do
    if line < State.line_count(state) do
      %{state | cursor: {line + 1, col}}
    else
      state
    end
  end

  defp move_cursor(%State{cursor: {line, _col}} = state, :line_start) do
    %{state | cursor: {line, 1}}
  end

  defp move_cursor(%State{cursor: {line, _col}} = state, :line_end) do
    current_line = State.get_line(state, line)
    %{state | cursor: {line, String.length(current_line) + 1}}
  end

  defp insert_char(%State{cursor: {line, col}, lines: lines} = state, char) do
    current_line = Enum.at(lines, line - 1, "")
    {before, after_cursor} = String.split_at(current_line, col - 1)
    new_line = before <> char <> after_cursor
    new_lines = List.replace_at(lines, line - 1, new_line)

    %{state | lines: new_lines, cursor: {line, col + 1}}
  end

  defp insert_newline(%State{cursor: {line, col}, lines: lines} = state) do
    current_line = Enum.at(lines, line - 1, "")
    {before, after_cursor} = String.split_at(current_line, col - 1)

    new_lines =
      lines
      |> List.replace_at(line - 1, before)
      |> List.insert_at(line, after_cursor)

    %{state | lines: new_lines, cursor: {line + 1, 1}}
  end

  defp delete_before_cursor(%State{cursor: {line, 1}} = state) when line > 1 do
    # At start of line - join with previous line
    prev_line = State.get_line(state, line - 1)
    current_line = State.get_line(state, line)
    new_line = prev_line <> current_line

    new_lines =
      state.lines
      |> List.replace_at(line - 2, new_line)
      |> List.delete_at(line - 1)

    %{state | lines: new_lines, cursor: {line - 1, String.length(prev_line) + 1}}
  end

  defp delete_before_cursor(%State{cursor: {line, col}} = state) when col > 1 do
    current_line = State.get_line(state, line)
    {before, after_cursor} = String.split_at(current_line, col - 1)
    new_line = String.slice(before, 0..-2//1) <> after_cursor
    new_lines = List.replace_at(state.lines, line - 1, new_line)

    %{state | lines: new_lines, cursor: {line, col - 1}}
  end

  defp delete_before_cursor(state), do: state

  defp delete_at_cursor(%State{cursor: {line, col}} = state) do
    current_line = State.get_line(state, line)
    line_length = String.length(current_line)

    cond do
      col <= line_length ->
        # Delete character at cursor
        {before, after_cursor} = String.split_at(current_line, col - 1)
        new_line = before <> String.slice(after_cursor, 1..-1//1)
        new_lines = List.replace_at(state.lines, line - 1, new_line)
        %{state | lines: new_lines}

      line < State.line_count(state) ->
        # At end of line - join with next line
        next_line = State.get_line(state, line + 1)
        new_line = current_line <> next_line

        new_lines =
          state.lines
          |> List.replace_at(line - 1, new_line)
          |> List.delete_at(line)

        %{state | lines: new_lines}

      true ->
        state
    end
  end
end
