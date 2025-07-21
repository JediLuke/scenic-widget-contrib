defmodule WidgetWorkbench.Scene do
  use Scenic.Scene
  require Logger

  alias Scenic.Graph
  alias Scenic.Primitives
  alias Scenic.Components
  alias Widgex.Frame
  alias Widgex.Frame.Grid
  alias Scenic.ViewPort
  alias WidgetWorkbench.Components.Modal
  alias WidgetWorkbench.Components.MenuBar

  @grid_color :light_gray
  # Customize the grid spacing
  @grid_spacing 40.0

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
      |> assign(current_file_index: 0)
      |> assign(component_files: [])
      |> push_graph(graph)

    # Request input events including viewport resize
    request_input(scene, [:cursor_pos, :cursor_button, :key, :viewport])

    {:ok, scene}
  end

  # Render function to build the graph using Widgex Grid
  defp render(%Frame{} = frame) do
    # Create a simple 1x1 grid that fills the entire frame
    grid = Grid.new(frame)
    |> Grid.columns([1.0])  # Single column that takes full width
    |> Grid.rows([1.0])     # Single row that takes full height
    
    # Calculate cell frames
    cell_frames = Grid.calculate(grid)
    
    # Get the single cell (0,0) and find its center
    main_cell = Grid.cell_frame(cell_frames, 0, 0)
    center_point = Frame.center(main_cell)
    
    # Build the graph - just white background with a dot in the center
    Graph.build()
    |> Primitives.rect({frame.size.width, frame.size.height}, fill: :white)
    |> draw_grid_background(frame)
    # Add a red circle at center using Grid layout
    |> Primitives.circle(30, fill: :red, translate: {center_point.x, center_point.y})
  end
  
  # Render UI elements using the grid
  defp render_grid_layout(graph, grid, cell_frames) do
    # Define named areas for better organization
    # Using {row, col, row_span, col_span} format
    grid_with_areas = grid
    |> Grid.define_areas(%{
      header: {0, 0, 1, 12},    # Row 0, all 12 columns
      sidebar: {1, 0, 7, 2},    # Rows 1-7, columns 0-1 (2 columns wide)
      content: {1, 2, 7, 10}    # Rows 1-7, columns 2-11 (10 columns wide)
    })
    
    # Get frames for each area using the passed cell_frames
    header_frame = Grid.area_frame(grid_with_areas, cell_frames, :header)
    sidebar_frame = Grid.area_frame(grid_with_areas, cell_frames, :sidebar)
    content_frame = Grid.area_frame(grid_with_areas, cell_frames, :content)
    
    graph
    # Render the header area with menu bar
    |> render_test_menu_bar(header_frame)
    # Render the sidebar with tools pane
    |> render_tools_pane(sidebar_frame)
    # Content area - keep simple for now
    |> Primitives.rect(
      {content_frame.size.width, content_frame.size.height},
      fill: {:color, {252, 252, 253}},
      stroke: {1, {:color, {220, 220, 230}}},
      translate: content_frame.pin.point
    )
    |> Primitives.text(
      "Widget Canvas",
      font_size: 14,
      fill: {:color, {100, 100, 110}},
      translate: {elem(content_frame.pin.point, 0) + 10, elem(content_frame.pin.point, 1) + 30}
    )
  end

  # Handle hot-reload message to re-render with updated code
  def handle_info(:hot_reload, scene) do
    # Get current frame and re-render with updated code
    frame = scene.assigns.frame
    new_graph = render(frame)
    
    scene = scene
    |> assign(graph: new_graph)
    |> push_graph(new_graph)
    
    {:noreply, scene}
  end

  # Function to draw a pseudo-grid background of "+"
  defp draw_grid_background(graph, %Frame{} = frame) do
    # Ensure we have integers by flooring the division results
    width_count = :math.floor(frame.size.width / @grid_spacing) |> trunc()
    height_count = :math.floor(frame.size.height / @grid_spacing) |> trunc()

    Enum.reduce(0..width_count, graph, fn x, acc ->
      Enum.reduce(0..height_count, acc, fn y, acc_inner ->
        acc_inner
        |> Primitives.text(
          "+",
          font_size: 16,
          fill: @grid_color,
          translate: {x * @grid_spacing, y * @grid_spacing}
        )
      end)
    end)
  end
  
  # Function to render the tools pane
  defp render_tools_pane(graph, %Frame{} = frame) do
    # Create a grid for the tools pane layout
    # Padding of 20px on all sides, but ensure positive dimensions
    padding = 20
    padded_width = max(frame.size.width - (padding * 2), 10)
    padded_height = max(frame.size.height - (padding * 2), 10)
    
    padded_frame = Frame.new(%{
      pin: {padding, padding},
      size: {padded_width, padded_height}
    })
    
    tools_grid = Grid.new(padded_frame)
    |> Grid.rows([60, 20, 50, 50, 1])  # Title, gap, button1, button2, remaining space
    |> Grid.columns([1])
    |> Grid.row_gap(10)
    |> Grid.define_areas(%{
      title: {0, 0, 1, 1},
      divider: {1, 0, 1, 1},
      open_button: {2, 0, 1, 1},
      create_button: {3, 0, 1, 1}
    })
    
    cell_frames = Grid.calculate(tools_grid)
    title_frame = Grid.area_frame(tools_grid, cell_frames, :title)
    divider_frame = Grid.area_frame(tools_grid, cell_frames, :divider)
    open_button_frame = Grid.area_frame(tools_grid, cell_frames, :open_button)
    create_button_frame = Grid.area_frame(tools_grid, cell_frames, :create_button)
    
    graph
    # Title
    |> Primitives.text(
      "WidgetWorkbench",
      font_size: 24,
      fill: {:color, {50, 50, 60, 255}},
      text_align: :center,
      translate: {title_frame.pin.x + title_frame.size.width / 2, title_frame.pin.y + 30}
    )
    # Divider line
    |> Primitives.line(
      {{frame.pin.x + 20, divider_frame.pin.y + 10}, 
       {frame.pin.x + frame.size.width - 20, divider_frame.pin.y + 10}},
      stroke: {1, {:color, {220, 220, 220, 255}}}
    )
    # Open Widget button
    |> Components.button(
      "Open Widget",
      id: :open_widget_button,
      width: open_button_frame.size.width,
      height: open_button_frame.size.height,
      translate: {open_button_frame.pin.x, open_button_frame.pin.y},
      theme: %{
        text: :black,
        background: {:color, {255, 255, 255, 255}},
        border: {:color, {200, 200, 200, 255}},
        active: {:color, {240, 240, 240, 255}},
        thumb: {:color, {180, 180, 180, 255}},
        focus: {:color, {0, 120, 212, 255}}
      }
    )
    # Create New Widget button
    |> Components.button(
      "Create New Widget",
      id: :create_widget_button,
      width: create_button_frame.size.width,
      height: create_button_frame.size.height,
      translate: {create_button_frame.pin.x, create_button_frame.pin.y},
      theme: %{
        text: :black,
        background: {:color, {255, 255, 255, 255}},
        border: {:color, {200, 200, 200, 255}},
        active: {:color, {240, 240, 240, 255}},
        thumb: {:color, {180, 180, 180, 255}},
        focus: {:color, {0, 120, 212, 255}}
      }
    )
  end

  # Function to render test menu bar
  defp render_test_menu_bar(graph, %Frame{} = frame) do
    # Sample menu structure for testing
    test_menu_map = %{
      file: {"File", [
        {:new_file, "New File"},
        {:open_file, "Open File"},
        {:save_file, "Save"},
        {:save_as, "Save As..."},
        {:quit, "Quit"}
      ]},
      edit: {"Edit", [
        {:undo, "Undo"},
        {:redo, "Redo"},
        {:cut, "Cut"},
        {:copy, "Copy"},
        {:paste, "Paste"}
      ]},
      view: {"View", [
        {:zoom_in, "Zoom In"},
        {:zoom_out, "Zoom Out"},
        {:reset_zoom, "Reset Zoom"},
        {:toggle_sidebar, "Toggle Sidebar"}
      ]},
      help: {"Help", [
        {:documentation, "Documentation"},
        {:about, "About"}
      ]}
    }
    
    # Position menubar at top of canvas with some margin
    # Ensure positive dimensions
    menubar_width = max(frame.size.width - 40, 100)
    
    menu_bar_data = %{
      frame: Frame.new(%{
        pin: {20, 20},
        size: {menubar_width, 30}
      }),
      menu_map: test_menu_map
    }
    
    graph
    |> MenuBar.add_to_graph(menu_bar_data, id: :test_menu_bar)
  end

  # Function to render the tool palette
  defp render_tool_palette(graph, %Frame{} = frame) do
    palette_width = 200
    palette_height = 90
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

  # Function to render file tabs
  defp render_file_tabs(graph, %Frame{} = frame) do
    tab_width = frame.size.width / 6
    tab_height = 40
    tab_y = frame.size.height - tab_height - 20

    # Draw tabs for each file
    graph
    |> Primitives.group(
      fn graph ->
        for i <- 0..5 do
          graph
          |> Components.button(
            "File #{i + 1}",
            id: {:file_tab, i},
            width: tab_width - 10,
            height: tab_height,
            translate: {i * tab_width + 5, tab_y}
          )
        end
      end,
      id: :file_tabs
    )
  end

  # Function to render the file editor
  defp render_file_editor(graph, %Frame{} = frame) do
    editor_width = frame.size.width - 40
    editor_height = frame.size.height - 200
    editor_x = 20
    editor_y = 100

    graph
    |> Primitives.group(
      fn graph ->
        graph
        # Draw the editor background
        |> Primitives.rect(
          {editor_width, editor_height},
          fill: :light_yellow,
          stroke: {1, :dark_gray},
          translate: {editor_x, editor_y}
        )
        # Add placeholder text for the editor
        |> Primitives.text(
          "Edit your component file here...",
          font_size: 18,
          fill: :black,
          translate: {editor_x + 10, editor_y + 30}
        )
      end,
      id: :file_editor
    )
  end

  @impl Scenic.Scene
  def handle_input({:viewport, {:reshape, {width, height}}}, _context, scene) do
    Logger.info("Viewport resized to #{width}x#{height}")
    
    # Update frame with new dimensions
    new_frame = Frame.new(%{pin: {0, 0}, size: {width, height}})
    
    # Re-render with new frame
    graph = render(new_frame)
    
    scene = scene
    |> assign(frame: new_frame)
    |> assign(graph: graph)
    |> push_graph(graph)
    
    {:noreply, scene}
  end
  
  # Keep the old handler in case the event name varies
  @impl Scenic.Scene
  def handle_input({:viewport, {:reshaped, {width, height}}}, _context, scene) do
    # Forward to the main handler
    handle_input({:viewport, {:reshape, {width, height}}}, _context, scene)
    
    {:noreply, scene}
  end

  def handle_input(input, _context, scene) do
    # Handle other input events if necessary
    Logger.debug("Widget Workbench received input: #{inspect(input)}")
    {:noreply, scene}
  end

  @impl Scenic.Scene
  def handle_event({:click, :open_widget_button}, _from, scene) do
    Logger.info("Open Widget button clicked!")
    # TODO: Show a list of available widgets to open
    # For now, let's just log it
    {:noreply, scene}
  end

  def handle_event({:click, :create_widget_button}, _from, scene) do
    Logger.info("Create New Widget button clicked!")
    # TODO: Show modal to create new widget with name input
    # For now, let's just log it
    {:noreply, scene}
  end

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

  def handle_event({:click, {:file_tab, index}}, _from, scene) do
    Logger.info("File tab #{index + 1} clicked!")

    # Update the current file index
    scene =
      scene
      |> assign(current_file_index: index)
      |> push_graph(scene.assigns.graph)

    {:noreply, scene}
  end

  def handle_cast({:open_widget, component}, scene) do
    IO.puts "Attempting to open #{inspect component}"
    {:noreply, scene}
  end

  def handle_event({:modal_submitted, component_name}, _from, scene) do
    Logger.info("Modal submitted with component name: #{component_name}")

    # Hide the modal
    graph = hide_modal(scene.assigns.graph)

    # Create new component files
    # TODO this isnt how that works
    # component_files = Flamelex.GUI.DevTools.build_new_component(component_name)
    # :ok = Flamelex.GUI.DevTools.build_new_component(component_name)
    {:ok, component} = WidgetWorkbench.ComponentBuilder.build_new_component(component_name)

    # TODO open the new component
    GenServer.cast(self(), {:open_widget, component})

    scene =
      scene
      |> assign(graph: graph)
      |> assign(modal_visible: false)
      # |> assign(component_files: component_files)
      |> push_graph(graph)

    {:noreply, scene}
  end

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
  
  def handle_event({:menu_item_clicked, item_id}, _from, scene) do
    Logger.info("Menu item clicked: #{inspect(item_id)}")
    
    # Handle different menu actions
    case item_id do
      :new_file ->
        Logger.info("Creating new file...")
      :quit ->
        Logger.info("Quit selected")
      _ ->
        Logger.info("Menu action: #{item_id}")
    end
    
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

  # Function to hide the modal
  defp hide_modal(graph) do
    graph
    |> Graph.modify(:modal_container, fn primitive ->
      %{primitive | data: []}
    end)
  end
end
