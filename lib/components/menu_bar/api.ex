defmodule ScenicWidgets.MenuBar.Api do
  @moduledoc """
  Public API for the MenuBar component.
  Provides functions to control the menu bar programmatically.
  """
  
  alias ScenicWidgets.MenuBar.State
  
  @doc """
  Set the active (open) menu programmatically.
  """
  def set_active_menu(%State{} = state, menu_id) do
    if has_menu?(state, menu_id) do
      %{state | active_menu: menu_id, hovered_item: menu_id, hovered_dropdown: nil}
    else
      state
    end
  end
  
  @doc """
  Close all open menus.
  """
  def close_all_menus(%State{} = state) do
    %{state | active_menu: nil, hovered_item: nil, hovered_dropdown: nil}
  end
  
  @doc """
  Check if a menu exists.
  """
  def has_menu?(%State{menu_map: menu_map}, menu_id) do
    Map.has_key?(menu_map, menu_id)
  end
  
  @doc """
  Get the list of all menu IDs.
  """
  def menu_ids(%State{menu_map: menu_map}) do
    Map.keys(menu_map)
  end
  
  @doc """
  Get the list of item IDs for a specific menu.
  """
  def menu_item_ids(%State{menu_map: menu_map}, menu_id) do
    case Map.get(menu_map, menu_id) do
      {_label, items} ->
        Enum.map(items, fn {item_id, _label} -> item_id end)
      nil ->
        []
    end
  end
  
  @doc """
  Update the menu map (add/remove menus or items).
  """
  def update_menu_map(%State{} = state, new_menu_map) do
    %{state | 
      menu_map: new_menu_map,
      dropdown_bounds: State.calculate_dropdown_bounds(state.frame, new_menu_map),
      active_menu: nil,
      hovered_item: nil,
      hovered_dropdown: nil
    }
  end
  
  @doc """
  Update the theme.
  """
  def update_theme(%State{} = state, theme) do
    %{state | theme: Map.merge(state.theme, theme)}
  end
end