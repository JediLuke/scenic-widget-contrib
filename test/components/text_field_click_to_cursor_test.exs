defmodule ScenicWidgets.TextFieldClickToCursorTest do
  use ExUnit.Case, async: true

  alias ScenicWidgets.TextField.State
  alias Widgex.Frame

  # Rows are font-size tall, offset by the renderer's 4px cursor-block nudge;
  # the text starts after 10px of padding (no gutter here).
  @font_size 16
  @padding 10

  defp state(lines, opts \\ []) do
    State.new(
      Map.merge(
        %{
          id: :editor,
          frame: Frame.new(%{pin: {0, 0}, size: {400, 300}}),
          initial_text: Enum.join(lines, "\n"),
          wrap_mode: :none,
          font: %{
            name: :ibm_plex_mono,
            size: @font_size,
            path: Path.expand("../../assets/fonts/IBMPlexMono-Regular.ttf", __DIR__)
          }
        },
        Map.new(opts)
      )
    )
  end

  defp row_y(row), do: 4 + (row - 1) * @font_size + div(@font_size, 2)

  test "a click on a line lands on that line" do
    assert {2, 1} = State.click_to_cursor(state(["alpha", "beta"]), {@padding, row_y(2)})
  end

  test "a click in the empty space below the document goes to the end of the last line" do
    assert {2, 5} = State.click_to_cursor(state(["alpha", "beta"]), {@padding, row_y(9)})
  end

  test "below the document, X does not matter: far left still means end of line" do
    assert {2, 5} = State.click_to_cursor(state(["alpha", "beta"]), {0, row_y(9)})
  end

  test "an empty last line is its own end" do
    assert {3, 1} = State.click_to_cursor(state(["alpha", "beta", ""]), {@padding, row_y(9)})
  end

  test "under word wrap the end of the last SOURCE line is where the click lands" do
    # 120px wide at 16px mono ≈ 12 chars of text; the last line wraps twice.
    s =
      state(["short", "the quick brown fox jumps over"],
        wrap_mode: :word,
        frame: Frame.new(%{pin: {0, 0}, size: {130, 300}})
      )

    assert {2, 31} = State.click_to_cursor(s, {@padding, row_y(12)})
  end
end
