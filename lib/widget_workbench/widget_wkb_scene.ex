defmodule WidgetWorkbench.Scene do
  use Scenic.Scene
  require Logger

  alias Scenic.Graph
  alias Scenic.Primitives
  alias Scenic.Components
  alias Widgex.Frame
  alias Scenic.ViewPort

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

    # Request input events
    request_input(scene, [:cursor_pos, :cursor_button, :key])

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
        # Add the tool palette
        |> render_tool_palette(frame)

        # Add more components or widgets here
      end,
      translate: frame.pin.point
    )
  end

  # Function to render the tool palette
  defp render_tool_palette(graph, %Frame{} = frame) do
    palette_width = 200
    palette_height = 100
    # Position on the right with a 20-pixel margin
    palette_x = frame.size.width - palette_width - 20
    # Position below the title text
    palette_y = 70

    # Draw the tool palette
    graph
    |> Primitives.group(
      fn graph ->
        graph
        # Draw the rounded rectangle background
        |> Primitives.rounded_rectangle(
          {palette_width, palette_height, 10},
          fill: :light_gray,
          stroke: {1, :dark_gray},
          translate: {0, 0}
        )
        # Add the "New Widget" button
        |> Components.button(
          "New Widget",
          id: :new_widget_button,
          width: palette_width - 20,
          height: 30,
          translate: {10, 10}
        )
        # Add the "Close Workbench" button
        |> Components.button(
          "Close Workbench",
          id: :close_workbench_button,
          width: palette_width - 20,
          height: 30,
          translate: {10, 50}
        )
      end,
      id: :tool_palette,
      translate: {palette_x, palette_y}
    )
  end

  @impl Scenic.Scene
  def handle_input(input, _context, scene) do
    # Handle input events if necessary
    Logger.debug("Widget Workbench received input: #{inspect(input)}")
    {:noreply, scene}
  end

  @impl Scenic.Scene
  def handle_event({:click, :new_widget_button}, _from, scene) do
    Logger.info("New Widget button clicked!")
    # Implement the action for creating a new widget here
    {:noreply, scene}
  end

  def handle_event({:click, :close_workbench_button}, _from, scene) do
    Logger.info("Close Workbench button clicked!")
    # Implement the action for closing the workbench
    # For example, switch back to the root scene:
    # {:ok, _} = ViewPort.set_root(scene.viewport, {Flamelex.GUI.RootScene, nil})
    {:noreply, scene}
  end

  def handle_event(_event, _from, scene), do: {:noreply, scene}
end
