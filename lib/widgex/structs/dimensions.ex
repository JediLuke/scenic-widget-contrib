defmodule Widgex.Structs.Dimensions do
  @moduledoc """
  A size: `width` and `height`, and the same pair as a `box` tuple, which is
  the shape Scenic's `rect/3` takes.

  Neither may be negative, which is what stops a split cut past the edge of
  its frame from producing a frame that cannot exist.
  """

  @type t :: %__MODULE__{width: number, height: number, box: {number, number}}

  defstruct width: nil,
            height: nil,
            box: {nil, nil}

  @spec new({number, number} | %{width: number, height: number}) :: t()
  def new({w, h}) do
    new(%{width: w, height: h})
  end

  def new(%{width: w, height: h}) when w >= 0 and h >= 0 do
    %__MODULE__{
      width: w,
      height: h,
      box: {w, h}
    }
  end
end
