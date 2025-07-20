defmodule WidgetWorkbench.Components.MenuBar.Reducer do
  @moduledoc """
  State reduction logic for the MenuBar component.
  Handles user input and state transitions.
  """
  
  alias WidgetWorkbench.Components.MenuBar.State
  
  @doc """
  Handle cursor position updates.
  """
  def handle_cursor_pos(%State{} = state, coords) do
    cond do
      # Check if cursor is in menu bar
      State.point_in_menu_bar?(state, coords) ->
        case State.find_hovered_menu(state, coords) do
          nil -> 
            %{state | hovered_item: nil}
          menu_id ->
            # If a dropdown is open and we hover a different menu, switch to it
            new_state = %{state | hovered_item: menu_id}
            if state.active_menu != nil && state.active_menu != menu_id do
              %{new_state | active_menu: menu_id, hovered_dropdown: nil}
            else
              new_state
            end
        end
      
      # Check if cursor is in active dropdown
      state.active_menu != nil ->
        case State.point_in_dropdown?(state, coords) do
          {true, item_id} ->
            %{state | hovered_dropdown: item_id, hovered_item: state.active_menu}
          {false, _} ->
            # Mouse left dropdown area - check if we should close it
            if outside_menu_area?(state, coords) do
              %{state | active_menu: nil, hovered_item: nil, hovered_dropdown: nil}
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
    cond do
      # Click on menu header
      State.point_in_menu_bar?(state, coords) ->
        case State.find_hovered_menu(state, coords) do
          nil -> 
            {:noop, state}
          menu_id ->
            if state.active_menu == menu_id do
              # Clicking active menu closes it
              new_state = %{state | active_menu: nil, hovered_dropdown: nil}
              {:noop, new_state}
            else
              # Open this menu
              new_state = %{state | active_menu: menu_id, hovered_dropdown: nil}
              {:noop, new_state}
            end
        end
      
      # Click in dropdown
      state.active_menu != nil ->
        case State.point_in_dropdown?(state, coords) do
          {true, item_id} when item_id != nil ->
            # Menu item clicked - close menu and notify parent
            new_state = %{state | active_menu: nil, hovered_item: nil, hovered_dropdown: nil}
            {:menu_item_clicked, item_id, new_state}
          _ ->
            # Click outside - close menu
            new_state = %{state | active_menu: nil, hovered_item: nil, hovered_dropdown: nil}
            {:noop, new_state}
        end
      
      # Click outside menu entirely
      true ->
        {:noop, state}
    end
  end
  
  defp outside_menu_area?(%State{frame: frame, dropdown_bounds: bounds, active_menu: menu_id}, {x, y}) do
    dropdown = Map.get(bounds, menu_id)
    
    # Check if outside menu bar
    outside_menu_bar = y < frame.pin.y || y > frame.pin.y + 30 ||
                      x < frame.pin.x || x > frame.pin.x + frame.size.width
    
    # Check if outside dropdown (if one is open)
    outside_dropdown = if dropdown do
      x < dropdown.x || x > dropdown.x + dropdown.width ||
      y < dropdown.y || y > dropdown.y + dropdown.height
    else
      true
    end
    
    outside_menu_bar && outside_dropdown
  end
end