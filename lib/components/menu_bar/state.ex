defmodule ScenicWidgets.MenuBar.State do
  @moduledoc """
  State management for the MenuBar component.
  """
  
  defstruct [
    :frame,
    :menu_map,
    :active_menu,      # Currently open dropdown menu ID
    :active_sub_menus, # Map of open sub-menu IDs by level
    :hovered_item,     # Currently hovered menu item
    :hovered_dropdown, # Currently hovered dropdown item
    :dropdown_bounds,  # Pre-calculated bounds for each dropdown
    :theme,
    :hover_activate    # If true, hovering opens menus instead of clicking
  ]
  
  @default_theme %{
    background: :dark_gray,
    text: :white,
    hover_bg: :steel_blue,
    hover_text: :white,
    dropdown_bg: :light_gray,
    dropdown_text: :black,
    dropdown_hover_bg: :dodger_blue,
    dropdown_hover_text: :white
  }
  
  @doc """
  Create a new MenuBar state from initialization data.
  """
  def new(data) do
    %__MODULE__{
      frame: data.frame,
      menu_map: data.menu_map,
      active_menu: nil,
      active_sub_menus: %{},
      hovered_item: nil,
      hovered_dropdown: nil,
      dropdown_bounds: calculate_dropdown_bounds(data.frame, data.menu_map),
      theme: Map.get(data, :theme, @default_theme),
      hover_activate: Map.get(data, :hover_activate, false)
    }
  end
  
  @doc """
  Calculate and cache the bounds for all dropdown menus.
  This allows us to pre-render them and just toggle visibility.
  """
  def calculate_dropdown_bounds(frame, menu_map) do
    menu_height = 40
    item_width = 150
    dropdown_item_height = 30  # Height of each dropdown item
    dropdown_padding = 5
    
    menu_map
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {{menu_id, {_label, items}}, index}, acc ->
      # Calculate dropdown position relative to component origin (0,0)
      x = index * item_width
      y = menu_height
      
      # Calculate dropdown height based on number of items
      dropdown_height = length(items) * dropdown_item_height + (2 * dropdown_padding)
      dropdown_width = item_width  # Match menu item width
      
      # Store bounds for this dropdown
      bounds = %{
        x: x,
        y: y,
        width: dropdown_width,
        height: dropdown_height,
        items: calculate_item_bounds(items, x, y, dropdown_width, dropdown_item_height, dropdown_padding)
      }
      
      Map.put(acc, menu_id, bounds)
    end)
  end
  
  defp calculate_item_bounds(items, dropdown_x, dropdown_y, width, item_height, padding) do
    items
    |> Enum.with_index()
    |> Enum.map(fn {item, index} ->
      # Each item starts at dropdown_y + padding, then offset by index * item_height
      item_y = dropdown_y + padding + (index * item_height)
      
      case item do
        {item_id, _label} when is_binary(item_id) ->
          # Regular menu item
          {item_id, %{
            x: dropdown_x + padding,  # Add padding for inner items
            y: item_y,
            width: width - (2 * padding),  # Account for padding on both sides
            height: item_height,
            type: :item
          }}
        
        {:sub_menu, label, sub_items} ->
          # Sub-menu item - use label as the ID for now
          sub_menu_id = "submenu_#{String.downcase(String.replace(label, " ", "_"))}"
          {sub_menu_id, %{
            x: dropdown_x + padding,
            y: item_y,
            width: width - (2 * padding),
            height: item_height,
            type: :sub_menu,
            label: label,
            items: sub_items
          }}
      end
    end)
    |> Enum.into(%{})
  end
  
  @doc """
  Check if a point is within the menu bar area.
  """
  def point_in_menu_bar?(%{frame: frame}, {x, y}) do
    # Check relative to component origin (0,0)
    x >= 0 &&
    x <= frame.size.width &&
    y >= 0 &&
    y <= 40
  end
  
  @doc """
  Check if a point is within any dropdown area.
  """
  def point_in_dropdown?(%{active_menu: nil}, _coords), do: {false, nil}
  def point_in_dropdown?(%{active_menu: menu_id, dropdown_bounds: bounds}, {x, y}) do
    case Map.get(bounds, menu_id) do
      nil -> 
        {false, nil}
      dropdown ->
        if x >= dropdown.x && x <= dropdown.x + dropdown.width &&
           y >= dropdown.y && y <= dropdown.y + dropdown.height do
          # Find which item is hovered
          hovered_item = find_hovered_dropdown_item(dropdown.items, {x, y})
          {true, hovered_item}
        else
          {false, nil}
        end
    end
  end
  
  defp find_hovered_dropdown_item(items, {x, y}) do
    Enum.find_value(items, fn {item_id, bounds} ->
      if x >= bounds.x && x <= bounds.x + bounds.width &&
         y >= bounds.y && y <= bounds.y + bounds.height do
        # Return both the item_id and its type
        {item_id, bounds.type}
      end
    end)
  end
  
  @doc """
  Find which menu header is being hovered.
  """
  def find_hovered_menu(%{menu_map: menu_map}, {x, _y}) do
    require Logger
    item_width = 150
    
    Logger.debug("find_hovered_menu: x=#{x}")
    
    menu_map
    |> Enum.with_index()
    |> Enum.find_value(fn {{menu_id, _}, index} ->
      # Check relative to component origin
      menu_x = index * item_width
      Logger.debug("Checking menu #{menu_id} at index #{index}: menu_x=#{menu_x}, x=#{x}")
      if x >= menu_x && x <= menu_x + item_width do
        menu_id
      end
    end)
  end
end