defmodule WidgetWorkbench.Scene do
  use Scenic.Scene
  require Logger

  alias Scenic.Graph
  alias Scenic.Primitives
  alias Widgex.Frame

  @moduledoc """
  A scene that serves as a widget workbench for designing and testing GUI components.
  """

  @impl Scenic.Scene
  def init(scene, _params, _opts) do
    # Get the viewport dimensions
    %{size: {width, height}} = scene.viewport

    # Create a frame for the scene
    frame = Frame.new(%{pin: {0, 0}, size: {width, height}})

    # Build the initial graph
    graph = render(frame)

    # Assign the graph to the scene and push it
    scene =
      scene
      |> assign(graph: graph)
      |> assign(frame: frame)
      |> push_graph(graph)

    # Request input events if needed
    # request_input(scene, [:cursor_pos, :cursor_button, :key])

    {:ok, scene}
  end

  # Render function to build the graph
  defp render(%Frame{} = frame) do
    Graph.build()
    |> Primitives.group(
      fn graph ->
        graph
        # Draw a background
        |> Primitives.rect({frame.size.width, frame.size.height}, fill: :white)
        # Add a placeholder text
        |> Primitives.text(
          "Widget Workbench",
          font_size: 32,
          fill: :black,
          text_align: :center,
          translate: {frame.size.width / 2, 50}
        )

        # Add more components or widgets here
      end,
      translate: frame.pin.point
    )
  end

  @impl Scenic.Scene
  def handle_input(input, _context, scene) do
    # Handle input events if necessary
    Logger.debug("Widget Workbench received input: #{inspect(input)}")
    {:noreply, scene}
  end
end
