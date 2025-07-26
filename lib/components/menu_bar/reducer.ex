defmodule ScenicWidgets.MenuBar.Reducer do
  @moduledoc """
  State reduction logic for the MenuBar component.
  Handles user input and state transitions.
  """
  
  alias ScenicWidgets.MenuBar.State
  
  @doc """
  Handle cursor position updates.
  """
  def handle_cursor_pos(%State{} = state, coords) do
    require Logger
    Logger.debug("Reducer.handle_cursor_pos: coords=#{inspect(coords)}, active_menu=#{inspect(state.active_menu)}")
    
    cond do
      # Check if cursor is in menu bar
      State.point_in_menu_bar?(state, coords) ->
        case State.find_hovered_menu(state, coords) do
          nil -> 
            Logger.debug("No menu hovered")
            %{state | hovered_item: nil}
          menu_id ->
            Logger.debug("Hovered menu: #{inspect(menu_id)}, current active: #{inspect(state.active_menu)}")
            new_state = %{state | hovered_item: menu_id}
            
            cond do
              # In hover_activate mode, open menu on hover
              state.hover_activate && state.active_menu == nil ->
                Logger.debug("Hover activate: opening menu #{inspect(menu_id)}")
                %{new_state | active_menu: menu_id, hovered_dropdown: nil, active_sub_menus: %{}}
              
              # If a dropdown is open and we hover a different menu, switch to it
              state.active_menu != nil && state.active_menu != menu_id ->
                Logger.debug("Switching active menu from #{inspect(state.active_menu)} to #{inspect(menu_id)}")
                %{new_state | active_menu: menu_id, hovered_dropdown: nil, active_sub_menus: %{}}
              
              true ->
                new_state
            end
        end
      
      # Check if cursor is in active dropdown
      state.active_menu != nil ->
        case State.point_in_dropdown?(state, coords) do
          {true, {item_id, :sub_menu}} ->
            # Hovering over a sub-menu item
            Logger.debug("Hovering over sub-menu: #{inspect(item_id)}")
            %{state | 
              hovered_dropdown: {state.active_menu, item_id}, 
              hovered_item: state.active_menu,
              active_sub_menus: Map.put(state.active_sub_menus, state.active_menu, item_id)
            }
          {true, {item_id, :item}} ->
            # Regular menu item
            %{state | 
              hovered_dropdown: {state.active_menu, item_id}, 
              hovered_item: state.active_menu,
              active_sub_menus: %{}
            }
          {false, _} ->
            # Mouse left dropdown area - check if we should close it
            if outside_menu_area?(state, coords) do
              %{state | active_menu: nil, hovered_item: nil, hovered_dropdown: nil, active_sub_menus: %{}}
            else
              %{state | hovered_dropdown: nil}
            end
        end
      
      # Cursor is outside menu area
      true ->
        %{state | hovered_item: nil, hovered_dropdown: nil}
    end
  end
  
  @doc """
  Handle click events.
  """
  def handle_click(%State{} = state, coords) do
    require Logger
    Logger.debug("Reducer.handle_click: coords=#{inspect(coords)}, frame=#{inspect(state.frame)}")
    
    cond do
      # Click on menu header
      State.point_in_menu_bar?(state, coords) ->
        Logger.debug("Click is in menu bar")
        case State.find_hovered_menu(state, coords) do
          nil -> 
            Logger.debug("No menu found at click position")
            {:noop, state}
          menu_id ->
            Logger.debug("Clicked on menu: #{inspect(menu_id)}")
            if state.active_menu == menu_id do
              # Clicking active menu closes it
              Logger.debug("Closing active menu: #{inspect(menu_id)}")
              new_state = %{state | active_menu: nil, hovered_dropdown: nil}
              {:noop, new_state}
            else
              # Open this menu
              Logger.debug("Opening menu: #{inspect(menu_id)}")
              new_state = %{state | active_menu: menu_id, hovered_dropdown: nil}
              {:noop, new_state}
            end
        end
      
      # Click in dropdown
      state.active_menu != nil ->
        case State.point_in_dropdown?(state, coords) do
          {true, {item_id, :sub_menu}} ->
            # Clicked on sub-menu - don't close, just activate it
            Logger.debug("Clicked on sub-menu: #{inspect(item_id)}")
            new_state = %{state | active_sub_menus: Map.put(state.active_sub_menus, state.active_menu, item_id)}
            {:noop, new_state}
          {true, {item_id, :item}} ->
            # Regular menu item clicked - close menu and notify parent
            new_state = %{state | active_menu: nil, hovered_item: nil, hovered_dropdown: nil, active_sub_menus: %{}}
            {:menu_item_clicked, item_id, new_state}
          _ ->
            # Click outside - close menu
            new_state = %{state | active_menu: nil, hovered_item: nil, hovered_dropdown: nil, active_sub_menus: %{}}
            {:noop, new_state}
        end
      
      # Click outside menu entirely
      true ->
        {:noop, state}
    end
  end
  
  defp outside_menu_area?(%State{frame: frame, dropdown_bounds: bounds, active_menu: menu_id, active_sub_menus: sub_menus} = state, {x, y}) do
    dropdown = Map.get(bounds, menu_id)
    
    # Check if outside menu bar (relative to component origin)
    outside_menu_bar = y < 0 || y > 40 ||
                      x < 0 || x > frame.size.width
    
    # Check if outside dropdown (if one is open)
    outside_dropdown = if dropdown do
      # Base dropdown bounds
      in_dropdown = x >= dropdown.x && x <= dropdown.x + dropdown.width &&
                   y >= dropdown.y && y <= dropdown.y + dropdown.height
      
      # Check if we're in any active sub-menu area
      # When a sub-menu is active, expand the valid area to include the gap between menus
      in_submenu_area = if map_size(sub_menus) > 0 do
        # For now, just add a grace area to the right of the dropdown when sub-menus are active
        # This allows diagonal mouse movement
        grace_width = 100  # pixels of grace area
        x >= dropdown.x && x <= dropdown.x + dropdown.width + grace_width &&
        y >= dropdown.y && y <= dropdown.y + dropdown.height
      else
        false
      end
      
      not (in_dropdown or in_submenu_area)
    else
      true
    end
    
    outside_menu_bar && outside_dropdown
  end
  
  def handle_escape(%State{} = state) do
    # Close any open menus on escape key
    if state.active_menu do
      %{state | active_menu: nil, hovered_item: nil, hovered_dropdown: nil, active_sub_menus: %{}}
    else
      state
    end
  end
end