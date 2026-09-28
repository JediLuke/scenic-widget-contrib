defmodule Widgex.Frame do
  @moduledoc """
  A rectangle on screen: its top-left corner (`pin`) and its `size`.

  Components take a frame to know where they sit and how much room they
  have. Frames split into rows and columns (`v_split/2`, `h_split/2`,
  `col_split/2`), which is how a whole window gets laid out:

      frame = Widgex.Frame.new(viewport)
      [menu_bar, rest] = Widgex.Frame.v_split(frame, px: 40)
      [sidebar, editor] = Widgex.Frame.h_split(rest, px: 240)

  `pin` is a `Widgex.Structs.Coordinates` and `size` a
  `Widgex.Structs.Dimensions`, so a frame reads as `frame.pin.x` or
  `frame.size.width`, and hands Scenic its tuples as `frame.pin.point` and
  `frame.size.box`.
  """

  alias Widgex.Structs.Coordinates
  alias Widgex.Structs.Dimensions

  @type t :: %__MODULE__{pin: Coordinates.t(), size: Dimensions.t()}

  defstruct pin: nil,
            size: nil

  defdelegate v_split(frame, args), to: Widgex.Frame.Utils

  defdelegate h_split(frame), to: Widgex.Frame.Utils
  defdelegate h_split(frame, args), to: Widgex.Frame.Utils

  defdelegate col_split(frame, n), to: Widgex.Frame.Utils

  defdelegate shrink(frame, factor, args), to: Widgex.Frame.Utils

  @doc """
  Make a frame.

  From a `Scenic.ViewPort`, a frame covering it. Otherwise from a `pin` and a
  `size`, each given as a tuple or as a map (`%{x:, y:}`, `%{width:, height:}`):

      iex> Widgex.Frame.new(pin: {10, 20}, size: {300, 200}).size.box
      {300, 200}

      iex> Widgex.Frame.new(%{pin: %{x: 10, y: 20}, size: {300, 200}}).pin.point
      {10, 20}
  """
  @spec new(Scenic.ViewPort.t() | keyword | map) :: t()
  def new(%Scenic.ViewPort{size: {vp_width, vp_height}}) do
    # One pixel wider than the viewport: without it a dark strip shows down
    # the right-hand edge. Why it does has not been tracked down yet.
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
  The middle of the frame.

      iex> alias Widgex.{Frame, Structs.Coordinates, Structs.Dimensions}
      iex> frame = %Frame{pin: %Coordinates{x: 10, y: 10}, size: %Dimensions{width: 100, height: 50}}
      iex> Frame.center(frame)
      %Coordinates{x: 60.0, y: 35.0, point: {60.0, 35.0}}
  """
  @spec center(t()) :: Coordinates.t()
  def center(%__MODULE__{
        pin: %Coordinates{x: pin_x, y: pin_y},
        size: %Dimensions{width: size_x, height: size_y}
      }) do
    x = pin_x + size_x / 2
    y = pin_y + size_y / 2

    %Coordinates{
      x: x,
      y: y,
      point: {x, y}
    }
  end

  @doc """
  The top-left corner, which is the pin.

      iex> Widgex.Frame.new(pin: {10, 10}, size: {100, 50}) |> Widgex.Frame.top_left()
      %Widgex.Structs.Coordinates{x: 10, y: 10, point: {10, 10}}
  """
  @spec top_left(t()) :: Coordinates.t()
  def top_left(%__MODULE__{pin: %Coordinates{x: tl_x, y: tl_y}}) do
    %Coordinates{
      x: tl_x,
      y: tl_y,
      point: {tl_x, tl_y}
    }
  end

  @doc """
  The bottom-left corner.

      iex> Widgex.Frame.new(pin: {10, 10}, size: {100, 50}) |> Widgex.Frame.bottom_left()
      %Widgex.Structs.Coordinates{x: 10, y: 60, point: {10, 60}}
  """
  @spec bottom_left(t()) :: Coordinates.t()
  def bottom_left(%__MODULE__{pin: %Coordinates{x: tl_x, y: tl_y}, size: %Dimensions{height: h}}) do
    %Coordinates{
      x: tl_x,
      y: tl_y + h,
      point: {tl_x, tl_y + h}
    }
  end

  @doc """
  The top-right corner.

      iex> Widgex.Frame.new(pin: {10, 10}, size: {100, 50}) |> Widgex.Frame.top_right()
      %Widgex.Structs.Coordinates{x: 110, y: 10, point: {110, 10}}
  """
  @spec top_right(t()) :: Coordinates.t()
  def top_right(%__MODULE__{pin: %Coordinates{x: tl_x, y: tl_y}, size: %Dimensions{width: w}}) do
    %Coordinates{
      x: tl_x + w,
      y: tl_y,
      point: {tl_x + w, tl_y}
    }
  end

  @doc """
  The bottom-right corner.

      iex> Widgex.Frame.new(pin: {10, 10}, size: {100, 50}) |> Widgex.Frame.bottom_right()
      %Widgex.Structs.Coordinates{x: 110, y: 60, point: {110, 60}}
  """
  @spec bottom_right(t()) :: Coordinates.t()
  def bottom_right(%__MODULE__{
        pin: %Coordinates{x: tl_x, y: tl_y},
        size: %Dimensions{width: w, height: h}
      }) do
    %Coordinates{
      x: tl_x + w,
      y: tl_y + h,
      point: {tl_x + w, tl_y + h}
    }
  end

  # ── Drawing a frame, for seeing where it is ───────────────────────────────
  #
  # Layout debugging aids. Each draws at the origin of the graph it is given;
  # translate the enclosing group to `frame.pin.point` to put it in place.

  @doc "An outline with an X corner to corner, in `color`."
  def draw_x_box(graph, %Widgex.Frame{} = frame, color: c) do
    graph
    |> Scenic.Primitives.group(fn graph ->
      graph
      |> Scenic.Primitives.rect(frame.size.box, stroke: {10, c})
      |> Scenic.Primitives.line({{0, 0}, {frame.size.width, frame.size.height}},
        stroke: {4, c}
      )
      |> Scenic.Primitives.line({{0, frame.size.height}, {frame.size.width, 0}},
        stroke: {4, c}
      )
    end)
  end

  @doc "A white X box. The same as `draw_guidewires/2`."
  def draw_guides(graph, frame) do
    graph
    |> draw_x_box(frame, color: :white)
  end

  @doc """
  A white X box, or, given `background:` (or `color:`, which means the same),
  a filled frame with a black X box over it.
  """
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
