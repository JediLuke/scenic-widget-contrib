defmodule Widgex.Frame.Utils do
  @moduledoc """
  Utility functions for working with frames.
  """
  alias Widgex.Frame

  @doc """
  Split a frame into two frames side by side, left then right.

  Cut at `px: n` pixels from the left edge, or at `fraction: f` (0.0 to 1.0)
  of the width. With no cut given, the frame is halved.
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
  def v_split(%Widgex.Frame{size: %{width: f_width}} = f, px: px) do
    # TODO assert that px < f.size.height
    # Top frame preserves the parent frame's pin position
    top = Frame.new(%{pin: f.pin.point, size: {f_width, px}})

    bottom =
      Frame.new(
        pin: {f.pin.x, f.pin.y + px},
        size: {f_width, f.size.height - px}
      )

    [top, bottom]
  end

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

  def shrink(%Widgex.Frame{} = f, factor, :top)
      when is_number(factor) and factor >= 0 and factor <= 1 do
    new_height = f.size.height * factor
    Widgex.Frame.new(%{pin: f.pin, size: {f.size.width, new_height}})
  end
end
