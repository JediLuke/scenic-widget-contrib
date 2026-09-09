defmodule ScenicWidgets.TextField.ReducerTest do
  use ExUnit.Case, async: true

  alias ScenicWidgets.TextField.{Reducer, State}

  test "store-backed command codepoints are ignored" do
    state = %State{focused: true}

    for modifier <- [[:ctrl], [:meta], [:super], [:ctrl, :shift]] do
      assert :ignore = Reducer.input_to_buffer_action(state, {:codepoint, {"s", modifier}})
    end

    assert {:insert, "é", :at_cursor} =
             Reducer.input_to_buffer_action(state, {:codepoint, {"é", [:alt]}})
  end

  test "store-backed unmodified codepoints remain insert actions" do
    state = %State{focused: true}

    assert {:insert, "s", :at_cursor} =
             Reducer.input_to_buffer_action(state, {:codepoint, {"s", []}})
  end

  # Double-click selects the word, cursor at the word's START: the range is
  # sent end-first because the store puts its cursor at the second position.
  test "store-backed double-click selects the word with the cursor at its start" do
    state =
      State.new(%{
        id: :editor,
        frame: Widgex.Frame.new(%{pin: {0, 0}, size: {400, 60}}),
        initial_text: "Hello world",
        input_mode: :store_backed,
        focused: true,
        font: %{
          name: :ibm_plex_mono,
          size: 16,
          path: Path.expand("../../assets/fonts/IBMPlexMono-Regular.ttf", __DIR__)
        }
      })

    click = {:cursor_button, {:btn_left, 1, [], {30, 10}}}

    assert {:click_move_cursor, clicked, {:set_cursor, {1, col}}} =
             Reducer.input_to_buffer_action(state, click)

    assert col in 2..5, "the click should land inside 'Hello', got column #{col}"

    assert {:double_click_select, _, {:select_range, {1, 6}, {1, 1}}} =
             Reducer.input_to_buffer_action(clicked, click)
  end

  test "store-backed undo and redo use canonical bindings" do
    state = %State{focused: true}

    assert :undo = Reducer.input_to_buffer_action(state, {:key, {:key_z, 1, [:ctrl]}})
    assert :redo = Reducer.input_to_buffer_action(state, {:key, {:key_z, 1, [:ctrl, :shift]}})
    assert nil == Reducer.input_to_buffer_action(state, {:key, {:key_u, 1, [:ctrl]}})
    assert nil == Reducer.input_to_buffer_action(state, {:key, {:key_r, 1, [:ctrl]}})
  end

  test "Shift+Tab emits unindent using the configured tab stop" do
    state = %State{focused: true, tab_width: 6}
    assert {:unindent, 6} = Reducer.input_to_buffer_action(state, {:key, {:key_tab, 1, [:shift]}})

    assert {:insert, "\t", :at_cursor} =
             Reducer.input_to_buffer_action(state, {:key, {:key_tab, 1, []}})
  end
end
