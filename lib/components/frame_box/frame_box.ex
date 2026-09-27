defmodule ScenicWidgets.FrameBox do
  @moduledoc """
  FrameBox is a simple component, used during development to quickly
  see what exact space a %Frame{} occupies.
  """
  use Scenic.Component
  require Logger
  alias Widgex.Frame

  @border_colors [
    :light_green,
    :red,
    :white,
    :black,
    :blue
  ]

  def validate(%{frame: %Frame{} = _f, color: color} = data) when is_atom(color) do
    {:ok, data}
  end

  def init(scene, args, _opts) do
    Logger.debug("#{__MODULE__} initializing...")

    init_graph =
      Scenic.Graph.build()
      |> Scenic.Primitives.rect(args.frame.size.box,
        fill: args.color,
        translate: args.frame.pin.point
      )
      |> Scenic.Primitives.rect(args.frame.size.box,
        stroke: {10, Enum.random(@border_colors)},
        translate: args.frame.pin.point
      )

    init_scene =
      scene
      |> assign(graph: init_graph)
      |> assign(frame: args.frame)
      |> push_graph(init_graph)

    {:ok, init_scene}
  end
end
