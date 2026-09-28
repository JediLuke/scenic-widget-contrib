defmodule Widgex.Frame.Utils do
  @moduledoc """
  Splitting and resizing frames. `Widgex.Frame` delegates these, so they are
  called as `Widgex.Frame.v_split/2` and so on.

  Every split tiles its frame exactly: the pieces share edges, and together
  they cover the frame. A cut past the frame's edge would make a piece of
  negative size, which `Widgex.Structs.Dimensions` refuses.
  """
  alias Widgex.Frame

  @doc """
  Split a frame into two frames side by side, left then right.

  Cut at `px: n` pixels from the left edge, or at `fraction: f` (a float
  from 0.0 to 1.0) of the width. With no cut given, the frame is halved.

      iex> frame = Widgex.Frame.new(pin: {0, 0}, size: {400, 100})
      iex> [left, right] = Widgex.Frame.h_split(frame, px: 100)
      iex> {left.size.box, right.pin.point, right.size.box}
      {{100, 100}, {100, 0}, {300, 100}}
  """
  def h_split(frame) do
    h_split(frame, fraction: 0.5)
  end

  def h_split(%Frame{} = f, px: px) do
    left =
      Frame.new(%{
        pin: f.pin.point,
        size: %{width: px, height: f.size.height}
      })

    right =
      Frame.new(%{
        pin: {
          f.pin.x + px,
          f.pin.y
        },
        size: %{
          width: f.size.width - px,
          height: f.size.height
        }
      })

    [left, right]
  end

  def h_split(%Frame{} = f, fraction: pc) when is_float(pc) and pc >= 0 and pc <= 1 do
    left =
      Frame.new(%{
        pin: f.pin.point,
        size: %{
          width: pc * f.size.width,
          height: f.size.height
        }
      })

    right =
      Frame.new(%{
        pin: {f.pin.x + pc * f.size.width, f.pin.y},
        size: %{width: (1 - pc) * f.size.width, height: f.size.height}
      })

    [left, right]
  end

  @doc """
  Split a frame into two frames stacked vertically, top then bottom, cut
  `px: n` pixels down from the top edge.

      iex> frame = Widgex.Frame.new(pin: {0, 0}, size: {400, 100})
      iex> [top, bottom] = Widgex.Frame.v_split(frame, px: 40)
      iex> {top.size.box, bottom.pin.point, bottom.size.box}
      {{400, 40}, {0, 40}, {400, 60}}
  """
  def v_split(%Widgex.Frame{size: %{width: f_width}} = f, px: px) do
    top = Frame.new(%{pin: f.pin.point, size: {f_width, px}})

    bottom =
      Frame.new(
        pin: {f.pin.x, f.pin.y + px},
        size: {f_width, f.size.height - px}
      )

    [top, bottom]
  end

  @doc """
  Split a frame into `n` columns of equal width, left to right.

      iex> frame = Widgex.Frame.new(pin: {0, 0}, size: {300, 50})
      iex> Widgex.Frame.col_split(frame, 3) |> Enum.map(& &1.pin.x)
      [0.0, 100.0, 200.0]
  """
  def col_split(%Frame{} = f, n) when is_integer(n) and n > 0 do
    col_width = f.size.width / n

    # col_num starts at zero and goes up to n-1, so n columns in total but 0 indexed
    Enum.map(0..(n - 1), fn col_num ->
      Frame.new(
        # Adjust pin based on the current column
        pin: {f.pin.x + col_num * col_width, f.pin.y},
        # Keep height consistent, only adjust width
        size: {col_width, f.size.height}
      )
    end)
  end

  @doc """
  Scale a frame's height by `factor` (0 to 1), keeping its top edge.
  `:top` is the only edge it keeps so far.
  """
  def shrink(%Widgex.Frame{} = f, factor, :top)
      when is_number(factor) and factor >= 0 and factor <= 1 do
    new_height = f.size.height * factor
    Widgex.Frame.new(%{pin: f.pin, size: {f.size.width, new_height}})
  end
end
