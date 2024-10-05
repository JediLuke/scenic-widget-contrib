defmodule WidgetWorkbench.Scene do
  use Scenic.Scene
  require Logger

  alias Scenic.Graph
  alias Scenic.Primitives
  alias Scenic.Components
  alias Widgex.Frame
  alias Scenic.ViewPort
  alias WidgetWorkbench.Components.Modal

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

    # Assign the graph and state to the scene
    scene =
      scene
      |> assign(graph: graph)
      |> assign(frame: frame)
      |> assign(modal_visible: false)
      |> push_graph(graph)

    # Request input events
    # request_input(scene, [:cursor_pos, :cursor_button, :key])

    {:ok, scene}
  end

  # # Render function to build the graph
  # defp render(%Frame{} = frame) do
  #   Graph.build()
  #   |> Primitives.group(
  #     fn graph ->
  #       graph
  #       # Draw a background
  #       |> Primitives.rect({frame.size.width, frame.size.height}, fill: :white)
  #       # Add a placeholder text
  #       |> Primitives.text(
  #         "Widget Workbench",
  #         font_size: 32,
  #         fill: :black,
  #         text_align: :center,
  #         translate: {frame.size.width / 2, 50}
  #       )
  #       # Add the tool palette
  #       |> render_tool_palette(frame)

  #       # Add more components or widgets here
  #     end,
  #     translate: frame.pin.point
  #   )
  # end

  # Modify the render function to include a modal container
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
        # Add a container for the modal
        |> Primitives.group(
          fn graph -> graph end,
          id: :modal_container
        )

        # Add more components or widgets here
      end,
      translate: frame.pin.point
    )
  end

  # Function to render the tool palette
  defp render_tool_palette(graph, %Frame{} = frame) do
    palette_width = 200
    palette_height = 100
    palette_x = frame.size.width - palette_width - 20
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

    # Show the modal
    graph = show_modal(scene.assigns.graph, scene.assigns.frame)

    scene =
      scene
      |> assign(graph: graph)
      |> assign(modal_visible: true)
      |> push_graph(graph)

    {:noreply, scene}
  end

  def handle_event({:click, :close_workbench_button}, _from, scene) do
    Logger.info("Close Workbench button clicked!")
    # switch back to Flamelex
    {:ok, _} = ViewPort.set_root(scene.viewport, Flamelex.GUI.RootScene, nil)
    {:noreply, scene}
  end

  def handle_event({:modal_submitted, component_name}, _from, scene) do
    Logger.info("Modal submitted with component name: #{component_name}")

    # Hide the modal
    graph = hide_modal(scene.assigns.graph)

    scene =
      scene
      |> assign(graph: graph)
      |> assign(modal_visible: false)
      |> push_graph(graph)

    # Implement the logic to handle the new component name
    # For now, we can just log it or update the scene as needed
    Flamelex.GUI.DevTools.build_new_component(component_name)

    {:noreply, scene}
  end

  # def handle_info({:modal_cancelled, _modal_pid}, scene) do
  def handle_event(:modal_cancelled, _from, scene) do
    Logger.info("Modal cancelled")

    # Hide the modal
    graph = hide_modal(scene.assigns.graph)

    scene =
      scene
      |> assign(graph: graph)
      |> assign(modal_visible: false)
      |> push_graph(graph)

    {:noreply, scene}
  end

  def handle_info(_msg, scene), do: {:noreply, scene}

  def handle_event(_event, _from, scene), do: {:noreply, scene}

  # Function to show the modal
  defp show_modal(graph, frame) do
    modal_id = :new_widget_modal

    graph
    |> Graph.add_to(:modal_container, fn g ->
      g
      |> Modal.add_to_graph(
        %{
          id: modal_id,
          frame: frame,
          title: "Enter Component Name",
          placeholder: "ComponentName"
        },
        id: modal_id
      )
    end)
  end

  defp hide_modal(graph) do
    graph
    |> Graph.modify(:modal_container, fn primitive ->
      %{primitive | data: []}
    end)
  end

  # defp hide_modal(graph) do
  #   graph
  #   |> Graph.modify(:modal_container, fn _primitive ->
  #     # nil
  #     # Replace with an empty group
  #     Scenic.Graph.build()
  #     |> Primitives.group(fn g -> g end, id: :modal_container)
  #   end)
  # end
end
