defmodule Widgex.Frame.Utils do
  @moduledoc """
  Utility functions for working with frames.
  """
  alias Widgex.Frame
  alias Widgex.Structs.Coordinates

  @doc """
  Split a frame into two frames, one to the left of the other.

  ## Parameters
    * `frame` - The frame to split.
    * `px` - The number of pixels to split the frame at.

  ## Returns
  A list of two frames, the first frame is the left frame, the second frame is the right frame.
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
  Split a frame into two frames, one above the other.

  ## Parameters
    * `frame` - The frame to split.
    * `px` - The number of pixels to split the frame at.

  ## Returns
  A list of two frames, the first frame is the top frame, the second frame is the bottom frame.
  """
  def v_split(%Frame{size: %{width: f_width}} = f, px: px) do
    # TODO assert that px < f.size.height
    top = Frame.new(%{pin: f.pin.point, size: {f_width, px}})

    bottom =
      Frame.new(
        pin: {f.pin.x, f.pin.y + px},
        size: {f_width, f.size.height - px}
      )

    [top, bottom]
  end

  # def col_split(%Frame{} = f, n) when is_integer(n) and n > 3 do
  #   col_width = f.size.width / n

  #   [
  #     Frame.new(pin: f.pin, size: {col_width, h}),
  #     Frame.new(pin: {f.pin.x + col_width, y}, size: {col_width, h}),
  #     Frame.new(pin: {f.pin.x + 2 * col_width, y}, size: {col_width, h})
  #   ]
  # end

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
end
