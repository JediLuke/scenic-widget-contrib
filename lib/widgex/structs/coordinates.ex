defmodule Widgex.Structs.Coordinates do
  @moduledoc """
  A point on screen: `x` and `y`, and the same pair as a `point` tuple, which
  is the shape Scenic's `translate:` option takes.

  Both must be zero or more: a frame is placed within the space it is drawn
  in, never before its origin.
  """

  @type t :: %__MODULE__{x: number, y: number, point: {number, number}}

  defstruct x: nil,
            y: nil,
            point: {nil, nil}

  @spec new({number, number} | %{x: number, y: number}) :: t()
  def new({x, y}) do
    new(%{x: x, y: y})
  end

  def new(%{x: x, y: y}) when x >= 0 and y >= 0 do
    %__MODULE__{
      x: x,
      y: y,
      point: {x, y}
    }
  end
end
