defmodule Widgex.Frame do
  @moduledoc """
  Represents a rectangular component, bound by a 2D box.

  A `Frame` in Widgex defines the spatial dimensions and location
  of a rectangular area in a 2D space. It is characterized by the
  coordinates of its top-left corner (`pin`) and its size (`size`),
  including the width (x dimension) and height (y dimension).
  """

  alias Widgex.Structs.Coordinates
  alias Widgex.Structs.Dimensions

  defstruct [
    # The Coordinates for the top-left point of this Frame
    pin: nil,
    # How large in {width, height} this Frame is
    size: nil
  ]

  defdelegate v_split(frame, args), to: Widgex.Frame.Utils

  defdelegate h_split(frame), to: Widgex.Frame.Utils
  defdelegate h_split(frame, args), to: Widgex.Frame.Utils

  # Make a new frame the same size as the ViewPort
  def new(%Scenic.ViewPort{size: {vp_width, vp_height}}) do
    # TODO why do we need this +1?? Without it we get a dark strip on the right hand side
    new(%{pin: {0, 0}, size: {vp_width + 1, vp_height}})
  end

  def new(pin: p, size: s) do
    new(%{pin: p, size: s})
  end

  def new(%{pin: %{x: x, y: y}, size: {w, h}}) do
    new(%{pin: {x, y}, size: {w, h}})
  end

  def new(%{pin: {x, y}, size: %{width: w, height: h}}) do
    new(%{pin: {x, y}, size: {w, h}})
  end

  def new(%{pin: %{x: x, y: y}, size: %{width: w, height: h}}) do
    new(%{pin: {x, y}, size: {w, h}})
  end

  def new(%{pin: {x, y}, size: {w, h}}) do
    %__MODULE__{
      pin: Coordinates.new({x, y}),
      size: Dimensions.new({w, h})
    }
  end

  @doc """
  The first page we ever learned to rule-up at school.

  +-----------------+
  |                 |
  +-----------------+   <-- linemark
  |                 |
  |                 |
  |                 |
  |                 |
  |                 |
  |                 |
  +-----------------+
  """

  # def new(
  #       %Scenic.ViewPort{size: {vp_width, vp_height}},
  #       {:standard_rule, frame: 1, linemark: linemark}
  #     ) do
  #   new(pin: {0, 0}, size: {vp_width, linemark})
  # end

  # def new(
  #       %Scenic.ViewPort{size: {vp_width, vp_height}},
  #       {:standard_rule, frame: 2, linemark: linemark}
  #     ) do
  #   new(pin: {0, linemark}, size: {vp_width, vp_height - linemark})
  # end

  # # return a frame the size of the entire viewport
  # def stack(
  #       %Scenic.ViewPort{size: {vp_width, vp_height}},
  #       :full_screen
  #     ) do
  #   [
  #     new(pin: {0, 0}, size: {vp_width, vp_height})
  #   ]
  # end

  # def stack(%Scenic.ViewPort{size: {_vp_width, vp_height}} = vp, :h_split) do
  #   # split it down the middle (horizontally)
  #   stack(vp, {:horizontal_split, {vp_height / 2, :px}})
  # end

  # # split the screen horizontally
  # def stack(
  #       %Scenic.ViewPort{size: {vp_width, vp_height}},
  #       {:horizontal_split, {split_point, :px}}
  #     ) do
  #   # The first page we ever learned to rule-up at school.
  #   #
  #   # +-----------------+
  #   # |                 |
  #   # +-----------------+   <-- divider (in pixels, from the top)
  #   # |                 |
  #   # |                 |
  #   # |                 |
  #   # |                 |
  #   # |                 |
  #   # |                 |
  #   # +-----------------+
  #   f1 = new(pin: {0, 0}, size: {vp_width, split_point})
  #   f2 = new(pin: {0, split_point}, size: {vp_width, vp_height - split_point})

  #   [f1, f2]
  # end

  # def stack(%Scenic.ViewPort{size: {vp_width, _vp_height}} = vp, :v_split) do
  #   # split it down the middle (vertically)
  #   stack(vp, {:vertical_split, {vp_width / 2, :px}})
  # end

  # def stack(
  #       %Scenic.ViewPort{size: {vp_width, vp_height}} = vp,
  #       {:vertical_split, {split, :ratio}}
  #     )
  #     when is_float(split) and split >= 0 and split <= 1 do
  #   stack(vp, {:vertical_split, {split * vp_width, :px}})
  # end

  # def stack(
  #       %Scenic.ViewPort{size: {vp_width, vp_height}},
  #       {:vertical_split, {split, :px}}
  #     ) do
  #   # The day someone discovers buffers in vim/emacs...
  #   #
  #   # +----------------------+
  #   # |           |          |
  #   # |           |          |
  #   # |           |          |
  #   # |           |          |
  #   # |<- split ->|          |
  #   # |           |          |
  #   # |           |          |
  #   # |           |          |
  #   # |           |          |
  #   # +----------------------+
  #   #             ^
  #   #           divider (in pixels, from the left)

  #   f1 = new(pin: {0, 0}, size: {split, vp_height})
  #   f2 = new(pin: {split, 0}, size: {vp_width - split, vp_height})

  #   [f1, f2]
  # end

  @doc """
  Constructs a new `Frame` struct that corresponds to the entire `Scenic.ViewPort`.

  Given a `Scenic.ViewPort`, this function will create a `Frame` that represents the entire viewport by utilizing the `size` attribute of the `ViewPort`.

  ## Params

  - `view_port`: The `Scenic.ViewPort` from which the frame is to be constructed.

  ## Examples

      iex> alias Scenic.ViewPort
      iex> alias Widgex.Structs.{Frame, Coordinates, Dimensions}
      iex> view_port = %ViewPort{size: {800, 600}}
      iex> Frame.from_viewport(view_port)
      %Frame{pin: %Coordinates{x: 0, y: 0}, size: %Dimensions{width: 800, height: 600}}
  """

  # @spec from_viewport(Scenic.ViewPort.t()) :: t()
  # def from_viewport(%Scenic.ViewPort{size: {vp_width, vp_height}}) do
  #   # Uncomment the line below to include the hack* (without it we get a dark strip on the right hand side)
  #   # width = vp_width + 1

  #   # Uncomment the line below for the intended behavior
  #   width = vp_width

  #   new(%Coordinates{x: 0, y: 0}, %Dimensions{width: width, height: vp_height})
  # end

  @doc """
  Computes the centroid of the given frame.

  The centroid is calculated as the mid-point of both dimensions of the frame.

  ## Params

  - `frame`: The `Frame` whose centroid is to be computed.

  ## Examples

      iex> alias Widgex.Structs.{Frame, Coordinates, Dimensions}
      iex> frame = %Frame{pin: %Coordinates{x: 10, y: 10}, size: %Dimensions{width: 100, height: 50}}
      iex> Frame.center(frame)
      %Coordinates{x: 60.0, y: 35.0}

  """
  def center(%__MODULE__{
        pin: %Coordinates{x: pin_x, y: pin_y},
        size: %Dimensions{width: size_x, height: size_y}
      }) do
    %Coordinates{
      x: pin_x + size_x / 2,
      y: pin_y + size_y / 2
    }
  end

  # def center(%{coords: c, dimens: d}) do
  #   Coordinates.new(x: c.x + d.width / 2, y: c.y + d.height / 2)
  # end

  # def center_tuple(%__MODULE__{} = frame) do
  #   Coordinates.point(center(frame))
  # end

  @doc """
  Computes the coordinates of the bottom-left corner of the given frame.

  ## Params

  - `frame`: The `Frame` whose bottom-left corner coordinates are to be computed.

  ## Examples

      iex> alias Widgex.Structs.{Frame, Coordinates, Dimensions}
      iex> frame = %Frame{pin: %Coordinates{x: 10, y: 10}, size: %Dimensions{width: 100, height: 50}}
      iex> Frame.bottom_left(frame)
      %Coordinates{x: 10, y: 60}

  """
  def top_left(%__MODULE__{pin: %Coordinates{x: tl_x, y: tl_y}}) do
    %Coordinates{
      x: tl_x,
      y: tl_y,
      point: {tl_x, tl_y}
    }
  end

  # @spec bottom_left(t()) :: Coordinates.t()
  def bottom_left(%__MODULE__{pin: %Coordinates{x: tl_x, y: tl_y}, size: %Dimensions{height: h}}) do
    # add the height dimension to the y-coordinate of the pin (top-left corner).
    %Coordinates{
      x: tl_x,
      y: tl_y + h,
      point: {tl_x, tl_y + h}
    }
  end

  def top_right(%__MODULE__{pin: %Coordinates{x: tl_x, y: tl_y}, size: %Dimensions{width: w}}) do
    # Add the width to the x-coordinate of the pin (top-left corner) to get the top-right corner.
    %Coordinates{
      x: tl_x + w,
      y: tl_y,
      point: {tl_x + w, tl_y}
    }
  end

  def bottom_right(%__MODULE__{
        pin: %Coordinates{x: tl_x, y: tl_y},
        size: %Dimensions{width: w, height: h}
      }) do
    # Add the width to the x-coordinate and the height to the y-coordinate of the pin (top-left corner).
    %Coordinates{
      x: tl_x + w,
      y: tl_y + h,
      point: {tl_x + w, tl_y + h}
    }
  end

  def draw_x_box(graph, frame, color: c) do
    graph
    |> Scenic.Primitives.rect(frame.size.box, stroke: {10, c})
    |> Scenic.Primitives.line({{0, 0}, {frame.size.width, frame.size.height}},
      stroke: {4, c}
    )
    |> Scenic.Primitives.line({{0, frame.size.height}, {frame.size.width, 0}},
      stroke: {4, c}
    )
  end

  # def draw_guidewires(graph, frame, background: background_color) do
  #   graph
  #   |> Scenic.Primitives.rect(frame.size.box, fill: background_color)
  #   |> Scenic.Primitives.rect(frame.size.box, stroke: {10, :white})
  #   |> Scenic.Primitives.line({top_left(frame).point, bottom_right(frame).point},
  #     stroke: {4, :black}
  #   )
  #   |> Scenic.Primitives.line({bottom_left(frame).point, top_right(frame).point},
  #     stroke: {4, :black}
  #   )
  # end

  def draw_guidewires(graph, frame) do
    graph
    |> draw_x_box(frame, color: :white)
  end

  def draw_guidewires(graph, frame, color: background_color) do
    draw_guidewires(graph, frame, background: background_color)
  end

  def draw_guidewires(graph, frame, background: background_color) do
    graph
    |> Scenic.Primitives.rect(frame.size.box, fill: background_color)
    |> draw_x_box(frame, color: :black)
  end
end
