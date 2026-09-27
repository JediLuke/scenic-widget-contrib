defmodule Widgex.FrameTest do
  use ExUnit.Case, async: true

  alias Widgex.Frame

  doctest Widgex.Frame

  defp frame(pin, size), do: Frame.new(pin: pin, size: size)

  defp rect(%Frame{pin: pin, size: size}), do: {pin.point, size.box}

  test "new/1 accepts tuples or maps for pin and size, and fills both forms in" do
    frame = frame({10, 20}, {300, 200})

    assert frame.pin.x == 10 and frame.pin.y == 20 and frame.pin.point == {10, 20}
    assert frame.size.width == 300 and frame.size.height == 200
    assert frame.size.box == {300, 200}
    assert Frame.new(%{pin: %{x: 10, y: 20}, size: %{width: 300, height: 200}}) == frame
  end

  test "v_split/2 cuts a band of px off the top" do
    [top, bottom] = Frame.v_split(frame({10, 20}, {300, 200}), px: 40)

    assert rect(top) == {{10, 20}, {300, 40}}
    assert rect(bottom) == {{10, 60}, {300, 160}}
  end

  test "h_split/2 by px puts px on the left" do
    [left, right] = Frame.h_split(frame({10, 20}, {300, 200}), px: 100)

    assert rect(left) == {{10, 20}, {100, 200}}
    assert rect(right) == {{110, 20}, {200, 200}}
  end

  test "h_split/2 by fraction, and h_split/1 halves" do
    f = frame({0, 0}, {400, 100})

    assert Enum.map(Frame.h_split(f, fraction: 0.25), &rect/1) ==
             [{{0, 0}, {100.0, 100}}, {{100.0, 0}, {300.0, 100}}]

    assert Frame.h_split(f) == Frame.h_split(f, fraction: 0.5)
  end

  test "col_split/2 makes n equal columns that tile the frame" do
    columns = Frame.col_split(frame({10, 0}, {300, 50}), 3)

    assert Enum.map(columns, &rect/1) ==
             [{{10, 0}, {100.0, 50}}, {{110.0, 0}, {100.0, 50}}, {{210.0, 0}, {100.0, 50}}]
  end

  test "shrink/3 keeps the top edge and scales the height" do
    assert rect(Frame.shrink(frame({10, 20}, {300, 200}), 0.5, :top)) ==
             {{10, 20}, {300, 100.0}}
  end
end
