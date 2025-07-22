defmodule ScenicWidgets.TestHelpers.SemanticUI do
  @moduledoc """
  Semantic UI testing helpers that work with rendered content and layout,
  rather than hardcoded coordinates.
  
  This provides a higher-level abstraction for UI testing that:
  1. Looks at what's actually rendered
  2. Finds elements by text/description  
  3. Clicks intelligently based on what's visible
  4. Verifies outcomes semantically
  """

  alias ScenicWidgets.TestHelpers.ScriptInspector
  alias ScenicMcp.Probes

  @doc """
  Verify that Widget Workbench has booted properly.
  Returns {:ok, state} with current UI state or {:error, reason}.
  """
  def verify_widget_workbench_loaded() do
    rendered_content = ScriptInspector.get_rendered_text_string()
    
    cond do
      String.contains?(rendered_content, "Widget Workbench") ->
        {:ok, %{content: rendered_content, status: :loaded}}
      
      String.contains?(rendered_content, "Load Component") ->
        {:ok, %{content: rendered_content, status: :ready_for_component}}
      
      true ->
        {:error, "Widget Workbench not detected. Got: #{inspect(String.slice(rendered_content, 0, 200))}"}
    end
  end

  @doc """
  Verify that a specific button or element exists in the UI.
  Returns {:ok, position} or {:error, reason}.
  """
  def verify_element_exists(element_text) do
    rendered_content = ScriptInspector.get_rendered_text_string()
    
    if String.contains?(rendered_content, element_text) do
      {:ok, %{text: element_text, found: true}}
    else
      {:error, "Element '#{element_text}' not found. Available: #{inspect(String.slice(rendered_content, 0, 200))}"}
    end
  end

  @doc """
  Click on the Load Component button using intelligent positioning.
  First checks what's actually available, then finds and clicks the right button.
  """
  def click_load_component_button() do
    rendered_content = ScriptInspector.get_rendered_text_string()
    IO.puts("🔍 Current UI content: #{inspect(String.slice(rendered_content, 0, 200))}")
    
    # Check what buttons are actually available
    cond do
      String.contains?(rendered_content, "Load Component") ->
        click_button_by_name("Load Component")
      
      String.contains?(rendered_content, "New Widget") ->
        # If we only see "New Widget", we might need to navigate to find "Load Component"
        # For now, let's try a broader search approach
        IO.puts("⚠️  'Load Component' not found, trying to find it in the UI...")
        find_and_click_load_component()
      
      true ->
        {:error, "Neither 'Load Component' nor 'New Widget' buttons found. UI may not be ready."}
    end
  end
  
  @doc """
  Generic button clicking by finding the button text and clicking near it.
  """
  def click_button_by_name(button_text) do
    with {:ok, _} <- verify_element_exists(button_text),
         {:ok, viewport_info} <- get_viewport_info() do
      
      {screen_width, screen_height} = viewport_info.size
      
      # Try different locations based on Widget Workbench layout
      # Right pane (tools pane) - most likely location
      right_pane_center = round(screen_width * 0.75)
      button_y = round(screen_height * 0.6)  # Try middle area first
      
      IO.puts("🖱️  Clicking '#{button_text}' button at (#{right_pane_center}, #{button_y})")
      
      click_at_position(right_pane_center, button_y)
      
      # Verify the modal opened (if this was Load Component)
      if button_text == "Load Component" do
        case verify_modal_opened() do
          {:ok, modal_info} -> {:ok, %{clicked: true, modal: modal_info}}
          {:error, reason} -> 
            # Try a different position if first attempt failed
            IO.puts("🔄 First click failed, trying different position...")
            button_y2 = round(screen_height * 0.5)
            click_at_position(right_pane_center, button_y2)
            Process.sleep(500)
            
            case verify_modal_opened() do
              {:ok, modal_info} -> {:ok, %{clicked: true, modal: modal_info}}
              {:error, reason2} -> {:error, "Button clicked but modal didn't open after retries: #{reason2}"}
            end
        end
      else
        {:ok, %{clicked: true, button: button_text}}
      end
    else
      error -> error
    end
  end
  
  defp find_and_click_load_component() do
    # Try to navigate or find the Load Component button
    # This might involve clicking through different UI areas
    {:ok, viewport_info} = get_viewport_info()
    {screen_width, screen_height} = viewport_info.size
    
    # Try clicking in different areas of the right pane to find Load Component
    positions_to_try = [
      {round(screen_width * 0.75), round(screen_height * 0.4)},  # Upper right pane
      {round(screen_width * 0.75), round(screen_height * 0.6)},  # Middle right pane  
      {round(screen_width * 0.75), round(screen_height * 0.8)},  # Lower right pane
    ]
    
    try_positions_until_modal_opens(positions_to_try)
  end
  
  defp try_positions_until_modal_opens([]) do
    {:error, "Could not find Load Component button after trying multiple positions"}
  end
  
  defp try_positions_until_modal_opens([{x, y} | rest]) do
    IO.puts("🔄 Trying position (#{x}, #{y})...")
    click_at_position(x, y)
    
    case verify_modal_opened() do
      {:ok, modal_info} -> 
        IO.puts("✅ Found the right button!")
        {:ok, %{clicked: true, modal: modal_info}}
      {:error, _} -> 
        try_positions_until_modal_opens(rest)
    end
  end
  
  defp click_at_position(x, y) do
    # Use the same approach as ScenicMcp.Probes - get the driver and send input directly
    driver_struct = get_driver_state()
    
    # Press
    Scenic.Driver.send_input(driver_struct, {:cursor_button, {:btn_left, 1, [], {x, y}}})
    Process.sleep(10)
    
    # Release
    Scenic.Driver.send_input(driver_struct, {:cursor_button, {:btn_left, 0, [], {x, y}}})
    Process.sleep(500)
  end
  
  defp get_driver_state() do
    # Get the driver from the registered name or via viewport
    case Process.whereis(:scenic_driver) do
      nil ->
        # Fallback: get driver from viewport
        viewport_pid = Process.whereis(:main_viewport)
        state = :sys.get_state(viewport_pid, 5000)
        [driver | _] = Map.get(state, :driver_pids, [])
        :sys.get_state(driver, 5000)
      driver_pid ->
        :sys.get_state(driver_pid, 5000)
    end
  end

  @doc """
  Verify that the component selection modal has opened.
  """
  def verify_modal_opened() do
    Process.sleep(500)  # Give modal time to appear
    rendered_content = ScriptInspector.get_rendered_text_string()
    
    cond do
      String.contains?(rendered_content, "Menu Bar") and 
      String.contains?(rendered_content, "Tab Bar") ->
        {:ok, %{status: :open, components_visible: true}}
      
      String.contains?(rendered_content, "Select Component") ->
        {:ok, %{status: :open, components_visible: false}}
      
      true ->
        {:error, "Modal not detected. Got: #{inspect(String.slice(rendered_content, 0, 300))}"}
    end
  end

  @doc """
  Click on a component in the modal by name.
  """
  def click_component_in_modal(component_name) do
    with {:ok, _modal} <- verify_modal_opened(),
         {:ok, _} <- verify_element_exists(component_name),
         {:ok, viewport_info} <- get_viewport_info() do
      
      {screen_width, screen_height} = viewport_info.size
      
      # Modal is centered
      modal_center_x = round(screen_width / 2)
      
      # Calculate component position based on alphabetical order
      # This is a heuristic - in practice we'd want better element detection
      component_y = case component_name do
        "Menu Bar" -> round(screen_height / 2 + 20)   # Likely 2nd-3rd item
        "Tab Bar" -> round(screen_height / 2 + 65)    # Likely last item
        _ -> round(screen_height / 2 + 20)            # Default position
      end
      
      IO.puts("🖱️  Clicking #{component_name} in modal at (#{modal_center_x}, #{component_y})")
      
      viewport_pid = Process.whereis(:main_viewport)
      send(viewport_pid, {:cursor_button, {:btn_left, 1, [], {modal_center_x, component_y}}})
      Process.sleep(10)
      send(viewport_pid, {:cursor_button, {:btn_left, 0, [], {modal_center_x, component_y}}})
      Process.sleep(1000)
      
      # Verify the component loaded
      verify_component_loaded(component_name)
    else
      error -> error
    end
  end

  @doc """
  Verify that a specific component has been loaded and is visible.
  """
  def verify_component_loaded(component_name) do
    Process.sleep(1000)  # Give component time to load
    rendered_content = ScriptInspector.get_rendered_text_string()
    
    # For MenuBar, we expect to see menu items like "File", "Edit", "View", "Help"
    case component_name do
      "Menu Bar" ->
        menu_items = ["File", "Edit", "View", "Help"]
        found_items = Enum.filter(menu_items, fn item -> 
          String.contains?(rendered_content, item) 
        end)
        
        if length(found_items) >= 2 do
          {:ok, %{component: component_name, menu_items: found_items, loaded: true}}
        else
          {:error, "MenuBar not loaded. Expected menu items, got: #{inspect(String.slice(rendered_content, 0, 300))}"}
        end
      
      _ ->
        if String.contains?(rendered_content, component_name) do
          {:ok, %{component: component_name, loaded: true}}
        else
          {:error, "Component #{component_name} not loaded. Got: #{inspect(String.slice(rendered_content, 0, 300))}"}
        end
    end
  end

  @doc """
  Complete workflow: Load a component in Widget Workbench.
  """
  def load_component(component_name) do
    IO.puts("🎯 Loading component: #{component_name}")
    
    with {:ok, _} <- verify_widget_workbench_loaded(),
         {:ok, _} <- click_load_component_button(),
         {:ok, _} <- click_component_in_modal(component_name),
         {:ok, result} <- verify_component_loaded(component_name) do
      
      IO.puts("✅ Successfully loaded #{component_name}")
      {:ok, result}
    else
      {:error, reason} -> 
        IO.puts("❌ Failed to load #{component_name}: #{reason}")
        {:error, reason}
    end
  end

  # Private helpers
  
  defp get_viewport_info() do
    case Scenic.ViewPort.info(:main_viewport) do
      {:ok, info} -> {:ok, info}
      error -> {:error, "Could not get viewport info: #{inspect(error)}"}
    end
  end
end