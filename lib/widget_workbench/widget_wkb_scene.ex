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

  @grid_color :light_gray
  # Customize the grid spacing
  @grid_spacing 40.0

  @moduledoc """
  A scene that serves as a widget workbench for designing and testing GUI components.
  """

  @impl Scenic.Scene
  def init(scene, _params, _opts) do
    # Register this process so hot reload can find it
    Process.register(self(), :_widget_workbench_scene_)
    
    # Try to get stored window size first (from previous resize events)
    {width, height} = try do
      case :ets.lookup(:widget_workbench_state, :current_size) do
        [{:current_size, stored_size}] ->
          Logger.info("🔍 Using stored window size: #{inspect(stored_size)}")
          stored_size
        [] ->
          # Table exists but no size stored yet
          size = scene.viewport.size
          :ets.insert(:widget_workbench_state, {:current_size, size})
          Logger.info("📐 Storing initial window size: #{inspect(size)}")
          size
      end
    rescue
      ArgumentError ->
        # Table doesn't exist - create it and use viewport size
        :ets.new(:widget_workbench_state, [:set, :public, :named_table])
        size = scene.viewport.size
        :ets.insert(:widget_workbench_state, {:current_size, size})
        Logger.info("📐 Created ETS table with initial window size: #{inspect(size)}")
        size
    end

    # Create a frame for the scene
    frame = Frame.new(%{pin: {0, 0}, size: {width, height}})

    # Build the initial graph
    graph = render(frame, nil, false)

    # Assign the graph and state to the scene
    scene =
      scene
      |> assign(graph: graph)
      |> assign(frame: frame)
      |> assign(modal_visible: false)
      |> assign(current_file_index: 0)
      |> assign(component_files: [])
      |> assign(selected_component: nil)
      |> assign(selected_component_module: nil)
      |> assign(component_modal_visible: false)
      |> push_graph(graph)

    # Request input events including viewport resize
    request_input(scene, [:cursor_pos, :cursor_button, :key, :viewport])

    {:ok, scene}
  end

  # Render function to build the graph using Widgex Grid
  defp render(%Frame{} = frame, selected_component \\ nil, show_modal \\ false) do
    # Create a grid with 2 columns: 2/3 for main area, 1/3 for constructor pane
    grid = Grid.new(frame)
    |> Grid.columns([2/3, 1/3])  # Two columns: main area (2/3) and constructor pane (1/3)
    |> Grid.rows([1.0])           # Single row that takes full height
    
    # Calculate cell frames
    cell_frames = Grid.calculate(grid)
    
    # Get the main area (left 2/3) and constructor pane (right 1/3)
    main_area = Grid.cell_frame(cell_frames, 0, 0)
    constructor_area = Grid.cell_frame(cell_frames, 0, 1)
    
    # Build the graph
    graph = Graph.build()
    # Render the main drawing area
    |> render_main_area(main_area, selected_component)
    # Render the constructor pane
    |> render_constructor_pane(constructor_area)
    
    # Add modal if needed
    if show_modal do
      graph |> render_component_selection_modal(frame)
    else
      graph
    end
  end
  
  # Render the main drawing area
  defp render_main_area(graph, %Frame{} = frame, selected_component) do
    graph
    # Main area background
    |> Primitives.rect(
      {frame.size.width, frame.size.height}, 
      fill: :white,
      translate: frame.pin.point
    )
    # Draw grid background
    |> draw_grid_background(frame)
    # Render content based on selection
    |> render_main_content(frame, selected_component)
  end
  
  # Render content in the main area
  defp render_main_content(graph, frame, nil) do
    # No component selected - show the yellow circle
    center_point = Frame.center(frame)
    graph
    |> Primitives.circle(30, fill: :green, translate: {center_point.x, center_point.y})
  end
  
  defp render_main_content(graph, frame, {component_name, component_module}) do
    # Component selected - render it centered in the frame
    center_point = Frame.center(frame)
    
    # Create a reasonable default frame for the component
    # We'll give it a 400x200 frame by default
    component_frame = Frame.new(%{
      pin: {center_point.x - 200, center_point.y - 100},
      size: {400, 200}
    })
    
    # Try different component loading strategies with better isolation
    try do
      # Strategy 1: Check if it has add_to_graph function
      if function_exported?(component_module, :add_to_graph, 3) do
        graph
        |> component_module.add_to_graph(prepare_component_data(component_module, component_frame), id: :loaded_component)
      else
        # Strategy 2: Use standard Scenic.Component pattern with timeout and isolation
        component_data = prepare_component_data(component_module, component_frame)
        Logger.info("Loading component #{component_name} with data: #{inspect(component_data)}")
        
        # Convert pin to tuple for Scenic compatibility
        translate_pin = case component_frame.pin do
          %Widgex.Structs.Coordinates{x: x, y: y} -> {x, y}
          {x, y} -> {x, y}
        end
        
        graph
        |> component_module.add_to_graph(
          component_data,
          id: :loaded_component,
          translate: translate_pin
        )
      end
    rescue
      error ->
        Logger.warn("Failed to load component #{component_name}: #{Exception.message(error)}")
        Logger.warn("Error details: #{inspect(error)}")
        
        # Show detailed error message
        error_text = case error do
          %FunctionClauseError{} -> "Invalid component format"
          %ArgumentError{} -> "Invalid arguments"
          _ -> Exception.message(error)
        end
        
        graph
        |> Primitives.text(
          "Failed to load: #{component_name}",
          font_size: 16,
          fill: :red,
          translate: {center_point.x, center_point.y - 20},
          text_align: :center
        )
        |> Primitives.text(
          error_text,
          font_size: 12,
          fill: :red,
          translate: {center_point.x, center_point.y + 10},
          text_align: :center
        )
        |> Primitives.text(
          "(Component isolation working!)",
          font_size: 10,
          fill: :green,
          translate: {center_point.x, center_point.y + 40},
          text_align: :center
        )
    catch
      :exit, reason ->
        Logger.warn("Component #{component_name} exited: #{inspect(reason)}")
        
        graph
        |> Primitives.text(
          "Component crashed: #{component_name}",
          font_size: 16,
          fill: :red,
          translate: {center_point.x, center_point.y},
          text_align: :center
        )
        |> Primitives.text(
          "(Workbench protected from crash)",
          font_size: 10,
          fill: :green,
          translate: {center_point.x, center_point.y + 30},
          text_align: :center
        )
    end
  end
  
  # Prepare component data based on the component type
  defp prepare_component_data(component_module, component_frame) do
    case component_module do
      ScenicWidgets.MenuBar ->
        # MenuBar needs menu_map and frame - use (0,0) pin since translate handles positioning
        better_frame = Frame.new(%{
          pin: {0, 0},  # Start at origin - translate will position it
          size: {component_frame.size.width, 40}  # Standard menubar height
        })
        
        %{
          frame: better_frame,
          menu_map: [
            {:sub_menu, "File", [
              {"new_file", "New File"},     # Fix: use string labels, not atoms
              {"open_file", "Open File"},
              {"save_file", "Save"},
              {"quit", "Quit"}
            ]},
            {:sub_menu, "Edit", [
              {"undo", "Undo"},
              {"redo", "Redo"},
              {"cut", "Cut"},
              {"copy", "Copy"},
              {"paste", "Paste"}
            ]},
            {:sub_menu, "Help", [
              {"about", "About"}
            ]}
          ]
        }
      
      ScenicWidgets.IconButton ->
        # Convert Coordinates struct to tuple format for IconButton  
        {pin_x, pin_y} = case component_frame.pin do
          %Widgex.Structs.Coordinates{x: x, y: y} -> {x, y}
          {x, y} -> {x, y}
        end
        
        # Create a new frame with tuple pin for IconButton
        icon_frame = Frame.new(%{
          pin: {pin_x, pin_y},
          size: component_frame.size
        })
        
        %{frame: icon_frame, text: "Icon Button"}
      
      ScenicWidgets.TextButton ->
        # TextButton might also need frame in a map
        %{frame: component_frame, text: "Text Button"}
      
      _ ->
        # Default: try frame parameter
        component_frame
    end
  end
  
  # Render the constructor pane on the right side
  defp render_constructor_pane(graph, %Frame{} = frame) do
    # Create a grid layout for the constructor pane
    pane_grid = Grid.new(frame)
    |> Grid.rows([20, 35, 30, 15, 50, 20, 50, 20, 50, 1])  # Top padding, title, subtitle, gap, reset, gap, new, gap, load, remaining
    |> Grid.columns([0.1, 0.8, 0.1])  # Small padding, large content area, small padding
    |> Grid.define_areas(%{
      title: {1, 1, 1, 1},
      subtitle: {2, 1, 1, 1},
      reset_button: {4, 1, 1, 1},
      new_button: {6, 1, 1, 1},
      load_button: {8, 1, 1, 1}
    })
    
    cell_frames = Grid.calculate(pane_grid)
    title_frame = Grid.area_frame(pane_grid, cell_frames, :title)
    subtitle_frame = Grid.area_frame(pane_grid, cell_frames, :subtitle)
    reset_button_frame = Grid.area_frame(pane_grid, cell_frames, :reset_button)
    new_button_frame = Grid.area_frame(pane_grid, cell_frames, :new_button)
    load_button_frame = Grid.area_frame(pane_grid, cell_frames, :load_button)
    
    graph
    # Grey background for constructor pane
    |> Primitives.rect(
      {frame.size.width, frame.size.height},
      fill: {:color, {230, 230, 235}},
      stroke: {1, {:color, {200, 200, 205}}},
      translate: frame.pin.point
    )
    # Add a title for the constructor pane
    |> Primitives.text(
      "Widget Workbench",
      font_size: 20,
      fill: {:color, {40, 40, 50}},
      translate: {elem(title_frame.pin.point, 0) + title_frame.size.width / 2, elem(title_frame.pin.point, 1) + 25},
      text_align: :center
    )
    # Add subtitle/help text
    |> Primitives.text(
      "Design & test Scenic components",
      font_size: 14,
      fill: {:color, {100, 100, 110}},
      translate: {elem(subtitle_frame.pin.point, 0) + subtitle_frame.size.width / 2, elem(subtitle_frame.pin.point, 1) + 20},
      text_align: :center
    )
    # Reset Scene button (red)
    |> Components.button(
      "Reset Scene",
      id: :reset_scene_button,
      width: reset_button_frame.size.width,
      height: reset_button_frame.size.height,
      translate: reset_button_frame.pin.point,
      theme: %{
        text: :white,
        background: {:color, {220, 53, 69}},
        border: {:color, {200, 33, 49}},
        active: {:color, {180, 13, 29}},
        thumb: {:color, {240, 73, 89}},
        focus: {:color, {160, 0, 19}}
      }
    )
    # New Widget button
    |> Components.button(
      "New Widget",
      id: :new_widget_button,
      width: new_button_frame.size.width,
      height: new_button_frame.size.height,
      translate: new_button_frame.pin.point,
      theme: %{
        text: :white,
        background: {:color, {70, 130, 180}},
        border: {:color, {60, 120, 170}},
        active: {:color, {50, 110, 160}},
        thumb: {:color, {80, 140, 190}},
        focus: {:color, {40, 100, 150}}
      }
    )
    # Load Component button
    |> Components.button(
      "Load Component",
      id: :load_component_button,
      width: load_button_frame.size.width,
      height: load_button_frame.size.height,
      translate: load_button_frame.pin.point,
      theme: %{
        text: :white,
        background: {:color, {34, 139, 34}},
        border: {:color, {24, 129, 24}},
        active: {:color, {14, 119, 14}},
        thumb: {:color, {44, 149, 44}},
        focus: {:color, {4, 109, 4}}
      }
    )
  end
  
  # Render the component selection modal
  defp render_component_selection_modal(graph, %Frame{} = frame) do
    # Create a centered modal frame
    modal_width = 400
    modal_height = 500
    modal_x = (frame.size.width - modal_width) / 2
    modal_y = (frame.size.height - modal_height) / 2
    
    # Dynamically discover components from /lib/components
    components = discover_components()
    
    graph
    # Semi-transparent overlay
    |> Primitives.rect(
      {frame.size.width, frame.size.height},
      fill: {:color, {0, 0, 0, 128}},
      translate: {0, 0}
    )
    # Modal background
    |> Primitives.rect(
      {modal_width, modal_height},
      fill: :white,
      stroke: {2, {:color, {100, 100, 100}}},
      translate: {modal_x, modal_y}
    )
    # Modal title
    |> Primitives.text(
      "Select Component",
      font_size: 18,
      fill: {:color, {40, 40, 50}},
      translate: {modal_x + modal_width / 2, modal_y + 30},
      text_align: :center
    )
    # Render component list
    |> render_component_list(components, modal_x, modal_y + 60, modal_width)
    # Cancel button
    |> Components.button(
      "Cancel",
      id: :cancel_component_selection,
      width: 80,
      height: 35,
      translate: {modal_x + modal_width - 90, modal_y + modal_height - 45},
      theme: %{
        text: :white,
        background: {:color, {150, 150, 150}},
        border: {:color, {130, 130, 130}},
        active: {:color, {120, 120, 120}},
        thumb: {:color, {160, 160, 160}},
        focus: {:color, {140, 140, 140}}
      }
    )
  end
  
  # Render the list of components as buttons
  defp render_component_list(graph, components, x, start_y, width) do
    button_height = 40
    button_margin = 5
    
    components
    |> Enum.with_index()
    |> Enum.reduce(graph, fn {{name, id}, index}, acc_graph ->
      y = start_y + (button_height + button_margin) * index
      
      acc_graph
      |> Components.button(
        name,
        id: {:select_component, id},
        width: width - 40,
        height: button_height,
        translate: {x + 20, y},
        theme: %{
          text: {:color, {50, 50, 60}},
          background: {:color, {245, 245, 250}},
          border: {:color, {200, 200, 210}},
          active: {:color, {70, 130, 180}},
          thumb: {:color, {220, 220, 230}},
          focus: {:color, {60, 120, 170}}
        }
      )
    end)
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

  # Discover components dynamically from /lib/components directory
  defp discover_components do
    components_dir = Path.join([File.cwd!(), "lib", "components"])
    
    if File.dir?(components_dir) do
      components_dir
      |> File.ls!()
      |> Enum.filter(&File.dir?(Path.join(components_dir, &1)))
      |> Enum.map(&discover_component_from_dir(&1, Path.join(components_dir, &1)))
      |> Enum.filter(& &1)  # Remove nils
      |> Enum.sort_by(fn {name, _} -> name end)  # Sort alphabetically
    else
      # Fallback to hardcoded list if directory doesn't exist
      [
        {"Test Pattern", ScenicWidgets.TestPattern},
        {"Frame Box", ScenicWidgets.FrameBox},
        {"Text Button", ScenicWidgets.TextButton}
      ]
    end
  end
  
  # Try to discover a component from a directory
  defp discover_component_from_dir(dir_name, dir_path) do
    # Look for the main component file (same name as directory)
    main_file = "#{dir_name}.ex"
    main_file_path = Path.join(dir_path, main_file)
    
    cond do
      File.exists?(main_file_path) ->
        # Convert directory name to module name
        module_name = dir_name |> Macro.camelize()
        display_name = dir_name |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")
        
        # Try to build the module atom - this might fail for non-standard modules
        try do
          module_atom = Module.concat([ScenicWidgets, module_name])
          {display_name, module_atom}
        rescue
          _ -> 
            # If module creation fails, still include it but mark it specially
            {display_name <> " (experimental)", String.to_atom("Elixir.ScenicWidgets.#{module_name}")}
        end
        
      true ->
        # Look for any .ex file in the directory
        case File.ls(dir_path) do
          {:ok, files} ->
            ex_files = Enum.filter(files, &String.ends_with?(&1, ".ex"))
            if length(ex_files) > 0 do
              # Use the first .ex file found
              file_name = List.first(ex_files) |> String.replace(".ex", "")
              module_name = file_name |> Macro.camelize()
              display_name = dir_name |> String.replace("_", " ") |> String.split(" ") |> Enum.map(&String.capitalize/1) |> Enum.join(" ")
              
              try do
                module_atom = Module.concat([ScenicWidgets, module_name])
                {display_name, module_atom}
              rescue
                _ -> 
                  {display_name <> " (experimental)", String.to_atom("Elixir.ScenicWidgets.#{module_name}")}
              end
            else
              nil  # No .ex files found
            end
          _ -> nil  # Can't read directory
        end
    end
  end

  # Handle hot-reload message to re-render with updated code
  def handle_info(:hot_reload, scene) do
    # Get size from multiple sources to debug
    stored_frame = scene.assigns.frame
    scene_viewport_size = scene.viewport.size
    
    {:ok, viewport_info} = Scenic.ViewPort.info(:main_viewport)
    vp_info_size = viewport_info.size
    
    Logger.info("Hot reload debug:")
    Logger.info("  - Stored frame size: #{inspect(stored_frame.size.box)}")
    Logger.info("  - scene.viewport.size: #{inspect(scene_viewport_size)}")
    Logger.info("  - ViewPort.info size: #{inspect(vp_info_size)}")
    
    # Use the stored frame size since that's what was last set by resize event
    current_frame = stored_frame
    
    # Re-render with current dimensions and selected component
    new_graph = render(current_frame, scene.assigns[:selected_component], scene.assigns[:component_modal_visible] || false)
    
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
    
    # Get frame origin position
    {frame_x, frame_y} = frame.pin.point

    Enum.reduce(0..width_count, graph, fn x, acc ->
      Enum.reduce(0..height_count, acc, fn y, acc_inner ->
        acc_inner
        |> Primitives.text(
          "+",
          font_size: 16,
          fill: @grid_color,
          translate: {frame_x + (x * @grid_spacing), frame_y + (y * @grid_spacing)}
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
    |> ScenicWidgets.MenuBar.add_to_graph(menu_bar_data, id: :test_menu_bar)
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
    
    # Store the new size in ETS for hot reload
    :ets.insert(:widget_workbench_state, {:current_size, {width, height}})
    
    # Update frame with new dimensions
    new_frame = Frame.new(%{pin: {0, 0}, size: {width, height}})
    
    # Re-render with new frame and selected component
    graph = render(new_frame, scene.assigns[:selected_component], scene.assigns[:component_modal_visible] || false)
    
    scene = scene
    |> assign(frame: new_frame)
    |> assign(graph: graph)
    |> push_graph(graph)
    
    {:noreply, scene}
  end
  
  # Keep the old handler in case the event name varies
  @impl Scenic.Scene  
  def handle_input({:viewport, {:reshaped, {width, height}}}, context, scene) do
    # Forward to the main handler
    handle_input({:viewport, {:reshape, {width, height}}}, context, scene)
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

  def handle_event({:click, :load_component_button}, _from, scene) do
    Logger.info("Load Component button clicked - showing component selection modal")
    
    # Show the component selection modal
    new_graph = render(scene.assigns.frame, scene.assigns.selected_component, true)
    
    scene = scene
    |> assign(component_modal_visible: true)
    |> assign(graph: new_graph)
    |> push_graph(new_graph)
    
    {:noreply, scene}
  end
  
  def handle_event({:click, :reset_scene_button}, _from, scene) do
    Logger.info("Reset Scene button clicked - clearing component and reloading")
    
    # Clear selected component and re-render
    new_graph = render(scene.assigns.frame, nil, false)
    
    scene = scene
    |> assign(selected_component: nil)
    |> assign(component_modal_visible: false)
    |> assign(graph: new_graph)
    |> push_graph(new_graph)
    
    {:noreply, scene}
  end
  
  def handle_event({:click, :new_widget_button}, _from, scene) do
    Logger.info("New Widget button clicked")
    {:noreply, scene}
  end
  
  def handle_event({:click, :cancel_component_selection}, _from, scene) do
    Logger.info("Component selection cancelled")
    
    # Hide the modal
    new_graph = render(scene.assigns.frame, scene.assigns.selected_component, false)
    
    scene = scene
    |> assign(component_modal_visible: false)
    |> assign(graph: new_graph)
    |> push_graph(new_graph)
    
    {:noreply, scene}
  end
  
  def handle_event({:click, {:select_component, component_module}}, _from, scene) do
    # Find the component info from our discovered list
    components = discover_components()
    selected = Enum.find(components, fn {_name, module} -> module == component_module end)
    
    Logger.info("Component selected: #{inspect(selected)}")
    
    # Re-render with the selected component and hide modal
    new_graph = render(scene.assigns.frame, selected, false)
    
    scene = scene
    |> assign(selected_component: selected)
    |> assign(component_modal_visible: false)
    |> assign(graph: new_graph)
    |> push_graph(new_graph)
    
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
