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
          f.pin.x,
          f.pin.y + px
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
        pin: {f.pin.x, f.pin.y + pc * f.size.width},
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
end
