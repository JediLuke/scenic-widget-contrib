defmodule WidgetWorkbench.Components.MenuBar.State do
  @moduledoc """
  State management for the MenuBar component.
  """
  
  defstruct [
    :frame,
    :menu_map,
    :active_menu,      # Currently open dropdown menu ID
    :hovered_item,     # Currently hovered menu item
    :hovered_dropdown, # Currently hovered dropdown item
    :dropdown_bounds,  # Pre-calculated bounds for each dropdown
    :theme
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
      hovered_item: nil,
      hovered_dropdown: nil,
      dropdown_bounds: calculate_dropdown_bounds(data.frame, data.menu_map),
      theme: Map.get(data, :theme, @default_theme)
    }
  end
  
  @doc """
  Calculate and cache the bounds for all dropdown menus.
  This allows us to pre-render them and just toggle visibility.
  """
  def calculate_dropdown_bounds(frame, menu_map) do
    menu_height = 40
    item_width = 150
    dropdown_padding = 5
    
    menu_map
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {{menu_id, {_label, items}}, index}, acc ->
      # Calculate dropdown position
      x = index * item_width
      y = menu_height
      
      # Calculate dropdown height based on number of items
      dropdown_height = length(items) * menu_height + (2 * dropdown_padding)
      dropdown_width = 200
      
      # Store bounds for this dropdown
      bounds = %{
        x: x,
        y: y,
        width: dropdown_width,
        height: dropdown_height,
        items: calculate_item_bounds(items, x, y, dropdown_width, menu_height, dropdown_padding)
      }
      
      Map.put(acc, menu_id, bounds)
    end)
  end
  
  defp calculate_item_bounds(items, x, y, width, item_height, padding) do
    items
    |> Enum.with_index()
    |> Enum.map(fn {{item_id, _label}, index} ->
      item_y = y + padding + (index * item_height)
      
      {item_id, %{
        x: x,
        y: item_y,
        width: width,
        height: item_height
      }}
    end)
    |> Enum.into(%{})
  end
  
  @doc """
  Check if a point is within the menu bar area.
  """
  def point_in_menu_bar?(%{frame: frame}, {x, y}) do
    x >= frame.pin.x &&
    x <= frame.pin.x + frame.size.width &&
    y >= frame.pin.y &&
    y <= frame.pin.y + 40
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
        item_id
      end
    end)
  end
  
  @doc """
  Find which menu header is being hovered.
  """
  def find_hovered_menu(%{menu_map: menu_map}, {x, _y}) do
    item_width = 150
    
    menu_map
    |> Enum.with_index()
    |> Enum.find_value(fn {{menu_id, _}, index} ->
      menu_x = index * item_width
      if x >= menu_x && x <= menu_x + item_width do
        menu_id
      end
    end)
  end
end