defmodule ScenicWidgets.TextField.Reducer do
  @moduledoc """
  Pure state transition functions for TextField.

  Phase 2: Input handling using ScenicEventsDefinitions
  Handles :key events and converts them to text using key2string/1

  Returns:
  - {:noop, state} - State changed, no parent notification needed
  - {:event, event_data, state} - State changed, notify parent
  """

  alias ScenicWidgets.TextField.State
  use ScenicWidgets.ScenicEventsDefinitions

  @doc """
  Process raw Scenic input events (for direct input mode).
  Uses ScenicEventsDefinitions for key matching and conversion.
  """

  # ===== TEXT INPUT - Using key2string conversion =====

  # Handle all valid text input characters (letters, numbers, punctuation, space, enter)
  def process_input(%State{focused: true} = state, input) when input in @valid_text_input_characters do
    char = key2string(input)
    new_state = insert_char(state, char)
    {:event, {:text_changed, state.id, State.get_text(new_state)}, new_state}
  end

  # ===== SPECIAL KEYS =====

  # Backspace - delete character before cursor
  def process_input(%State{focused: true} = state, @backspace_key) do
    new_state = delete_before_cursor(state)
    {:event, {:text_changed, state.id, State.get_text(new_state)}, new_state}
  end

  # Delete - delete character at cursor
  def process_input(%State{focused: true} = state, @delete_key) do
    new_state = delete_at_cursor(state)
    {:event, {:text_changed, state.id, State.get_text(new_state)}, new_state}
  end

  # Arrow keys - cursor movement
  def process_input(%State{focused: true} = state, @left_arrow) do
    {:noop, move_cursor(state, :left)}
  end

  def process_input(%State{focused: true} = state, @right_arrow) do
    {:noop, move_cursor(state, :right)}
  end

  def process_input(%State{focused: true} = state, @up_arrow) do
    {:noop, move_cursor(state, :up)}
  end

  def process_input(%State{focused: true} = state, @down_arrow) do
    {:noop, move_cursor(state, :down)}
  end

  # Home/End keys
  def process_input(%State{focused: true} = state, @home_key) do
    {:noop, move_cursor(state, :line_start)}
  end

  def process_input(%State{focused: true} = state, @end_key) do
    {:noop, move_cursor(state, :line_end)}
  end

  # Escape - clear focus (optionally)
  def process_input(%State{focused: true} = state, @escape_key) do
    {:event, {:focus_lost, state.id}, %{state | focused: false}}
  end

  # ===== KEYBOARD SHORTCUTS =====

  # Ctrl+A - Select all (Phase 3 - selection support)
  def process_input(%State{focused: true} = state, @ctrl_a) do
    # For now, just acknowledge
    {:noop, state}
  end

  # Ctrl+S - Save (emit event for parent to handle)
  def process_input(%State{focused: true} = state, @ctrl_s) do
    {:event, {:save_requested, state.id, State.get_text(state)}, state}
  end

  # ===== KEY RELEASE EVENTS - Ignore =====

  # Ignore key release events (state: 0)
  def process_input(state, {:key, {_key, @key_released, _mods}}) do
    {:noop, state}
  end

  # ===== UNFOCUSED - Ignore all keyboard input =====

  def process_input(%State{focused: false} = state, {:key, _}) do
    {:noop, state}
  end

  # ===== CLICK TO FOCUS =====

  # Click inside -> gain focus
  def process_input(%State{focused: false} = state, {:cursor_button, {:btn_left, 1, _, pos}}) do
    if State.point_inside?(state, pos) do
      {:event, {:focus_gained, state.id}, %{state | focused: true}}
    else
      {:noop, state}
    end
  end

  # Click outside -> lose focus
  def process_input(%State{focused: true} = state, {:cursor_button, {:btn_left, 1, _, pos}}) do
    if State.point_inside?(state, pos) do
      # Click inside while focused - move cursor to click position (Phase 3)
      {:noop, state}
    else
      {:event, {:focus_lost, state.id}, %{state | focused: false}}
    end
  end

  # ===== FALLBACK - Unhandled input =====

  def process_input(state, _input) do
    {:noop, state}
  end

  @doc """
  Process high-level actions (for external control mode).
  Phase 3 implementation.
  """
  def process_action(state, _action) do
    {:noop, state}
  end

  # ===== HELPER FUNCTIONS =====

  @doc """
  Insert character at cursor position.
  Handles newlines (\n) by splitting the current line.
  """
  defp insert_char(%State{lines: lines, cursor: {line_num, col}} = state, "\n") do
    # Handle Enter key - split current line
    current_line = Enum.at(lines, line_num - 1, "")
    {before, after_cursor} = String.split_at(current_line, col - 1)

    new_lines =
      lines
      |> List.replace_at(line_num - 1, before)
      |> List.insert_at(line_num, after_cursor)

    %{state | lines: new_lines, cursor: {line_num + 1, 1}}
  end

  defp insert_char(%State{lines: lines, cursor: {line_num, col}} = state, char) when is_binary(char) do
    current_line = Enum.at(lines, line_num - 1, "")
    {before, after_cursor} = String.split_at(current_line, col - 1)
    new_line = before <> char <> after_cursor

    new_lines = List.replace_at(lines, line_num - 1, new_line)

    %{state | lines: new_lines, cursor: {line_num, col + 1}}
  end

  @doc """
  Delete character before cursor (Backspace).
  """
  defp delete_before_cursor(%State{cursor: {1, 1}} = state) do
    # At start of document - nothing to delete
    state
  end

  defp delete_before_cursor(%State{lines: lines, cursor: {line_num, 1}} = state) do
    # At start of line - join with previous line
    if line_num > 1 do
      prev_line = Enum.at(lines, line_num - 2)
      current_line = Enum.at(lines, line_num - 1)
      new_line = prev_line <> current_line

      new_lines =
        lines
        |> List.replace_at(line_num - 2, new_line)
        |> List.delete_at(line_num - 1)

      new_col = String.length(prev_line) + 1
      %{state | lines: new_lines, cursor: {line_num - 1, new_col}}
    else
      state
    end
  end

  defp delete_before_cursor(%State{lines: lines, cursor: {line_num, col}} = state) do
    # Delete character before cursor in current line
    current_line = Enum.at(lines, line_num - 1, "")
    {before, after_cursor} = String.split_at(current_line, col - 1)
    new_before = String.slice(before, 0..-2//1)
    new_line = new_before <> after_cursor

    new_lines = List.replace_at(lines, line_num - 1, new_line)

    %{state | lines: new_lines, cursor: {line_num, max(1, col - 1)}}
  end

  @doc """
  Delete character at cursor (Delete key).
  """
  defp delete_at_cursor(%State{lines: lines, cursor: {line_num, col}} = state) do
    current_line = Enum.at(lines, line_num - 1, "")

    if col > String.length(current_line) do
      # At end of line - join with next line
      if line_num < length(lines) do
        next_line = Enum.at(lines, line_num)
        new_line = current_line <> next_line

        new_lines =
          lines
          |> List.replace_at(line_num - 1, new_line)
          |> List.delete_at(line_num)

        %{state | lines: new_lines}
      else
        state
      end
    else
      # Delete character at cursor
      {before, after_cursor} = String.split_at(current_line, col - 1)
      new_after = String.slice(after_cursor, 1..-1//1)
      new_line = before <> new_after

      new_lines = List.replace_at(lines, line_num - 1, new_line)
      %{state | lines: new_lines}
    end
  end

  @doc """
  Move cursor in specified direction.
  """
  defp move_cursor(%State{cursor: {line, col}, lines: lines} = state, :left) do
    if col > 1 do
      %{state | cursor: {line, col - 1}}
    else
      # At start of line - move to end of previous line
      if line > 1 do
        prev_line = Enum.at(lines, line - 2)
        %{state | cursor: {line - 1, String.length(prev_line) + 1}}
      else
        state
      end
    end
  end

  defp move_cursor(%State{cursor: {line, col}, lines: lines} = state, :right) do
    current_line = Enum.at(lines, line - 1, "")

    if col <= String.length(current_line) do
      %{state | cursor: {line, col + 1}}
    else
      # At end of line - move to start of next line
      if line < length(lines) do
        %{state | cursor: {line + 1, 1}}
      else
        state
      end
    end
  end

  defp move_cursor(%State{cursor: {line, col}, lines: lines} = state, :up) do
    if line > 1 do
      prev_line = Enum.at(lines, line - 2)
      new_col = min(col, String.length(prev_line) + 1)
      %{state | cursor: {line - 1, new_col}}
    else
      state
    end
  end

  defp move_cursor(%State{cursor: {line, col}, lines: lines} = state, :down) do
    if line < length(lines) do
      next_line = Enum.at(lines, line)
      new_col = min(col, String.length(next_line) + 1)
      %{state | cursor: {line + 1, new_col}}
    else
      state
    end
  end

  defp move_cursor(%State{cursor: {line, _col}} = state, :line_start) do
    %{state | cursor: {line, 1}}
  end

  defp move_cursor(%State{cursor: {line, _col}, lines: lines} = state, :line_end) do
    current_line = Enum.at(lines, line - 1, "")
    %{state | cursor: {line, String.length(current_line) + 1}}
  end
end
