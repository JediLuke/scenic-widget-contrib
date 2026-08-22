defmodule ScenicWidgets.FilePicker.ScrollTest do
  use ExUnit.Case, async: true

  alias ScenicWidgets.FilePicker.{Reducer, State}
  alias Widgex.Scroll.ScrollState

  test "wheel-down moves the file list toward later entries" do
    scroll = %ScrollState{
      offset_y: 100,
      content_height: 1_000,
      viewport_height: 200,
      direction: :vertical,
      scroll_speed: 40
    }

    state = %State{scroll: scroll}

    assert {:state, updated} =
             Reducer.process_input(state, {:cursor_scroll, {{0, -1}, {20, 20}}})

    assert updated.scroll.offset_y > scroll.offset_y
  end
end
