#!/usr/bin/env elixir

# Simple test to verify Scenic is working

Code.prepend_path("_build/dev/lib/scenic_widget_contrib/ebin")
Code.prepend_path("_build/dev/lib/scenic/ebin")
Code.prepend_path("_build/dev/lib/scenic_driver_local/ebin")
Code.prepend_path("_build/dev/lib/font_metrics/ebin")
Code.prepend_path("_build/dev/lib/truetype_metrics/ebin")
Code.prepend_path("_build/dev/lib/ex_image_info/ebin")
Code.prepend_path("_build/dev/lib/nimble_options/ebin")
Code.prepend_path("_build/dev/lib/input_event/ebin")

defmodule SimpleScene do
  use Scenic.Scene
  alias Scenic.Graph
  
  @impl Scenic.Scene
  def init(scene, _args, _opts) do
    graph = 
      Graph.build()
      |> Scenic.Primitives.text("Hello Scenic!", translate: {20, 20})
    
    scene = push_graph(scene, graph)
    
    {:ok, scene}
  end
end

# Start applications
{:ok, _} = Application.ensure_all_started(:logger)
{:ok, _} = Application.ensure_all_started(:scenic)
{:ok, _} = Application.ensure_all_started(:scenic_driver_local)

# Create viewport config
config = [
  name: :main_viewport,
  size: {800, 600},
  default_scene: {SimpleScene, nil},
  drivers: [
    [
      module: Scenic.Driver.Local,
      name: :local,
      window: [
        title: "Simple Scenic Test"
      ]
    ]
  ]
]

# Start viewport
case Scenic.ViewPort.start(config) do
  {:ok, pid} ->
    IO.puts("Scenic started! PID: #{inspect(pid)}")
    Process.sleep(:infinity)
  {:error, reason} ->
    IO.puts("Failed to start: #{inspect(reason)}")
end