defmodule WidgetWorkbench.Components.MenuBar.Renderizer do
  @moduledoc """
  Rendering logic for the MenuBar component.
  Pre-renders all dropdowns and toggles visibility to avoid flickering.
  """
  
  alias Scenic.Graph
  alias Scenic.Primitives
  alias WidgetWorkbench.Components.MenuBar.State
  
  @menu_height 30
  @item_width 150
  @dropdown_item_height 30
  @dropdown_padding 5
  
  @doc """
  Render the complete menu bar with all dropdowns pre-rendered.
  """
  def render(graph, %State{} = state) do
    graph
    |> render_background(state)
    |> render_menu_headers(state)
    |> render_all_dropdowns(state)
    |> add_semantic_data(state)
  end
  
  @doc """
  Update an existing graph in place (renderizer pattern).
  """
  def update_graph(existing_graph, %State{} = state) do
    # TODO: Implement efficient graph updates
    # For now, just re-render completely
    render(Graph.build(), state)
  end
  
  defp render_background(graph, %State{frame: frame, theme: theme}) do
    graph
    |> Primitives.rect(
      {frame.size.width, @menu_height},
      fill: theme.background,
      translate: {frame.pin.x, frame.pin.y},
      id: :menu_bar_background
    )
  end
  
  defp render_menu_headers(graph, %State{menu_map: menu_map} = state) do
    menu_map
    |> Enum.with_index()
    |> Enum.reduce(graph, fn {{menu_id, {label, _items}}, index}, g ->
      render_menu_header(g, menu_id, label, index, state)
    end)
  end
  
  defp render_menu_header(graph, menu_id, label, index, %State{} = state) do
    x = state.frame.pin.x + (index * @item_width)
    y = state.frame.pin.y
    
    # Determine if this header is active or hovered
    is_active = state.active_menu == menu_id
    is_hovered = state.hovered_item == menu_id
    
    # Background color based on state
    bg_color = cond do
      is_active -> state.theme.hover_bg
      is_hovered -> state.theme.hover_bg
      true -> state.theme.background
    end
    
    text_color = cond do
      is_active -> state.theme.hover_text
      is_hovered -> state.theme.hover_text
      true -> state.theme.text
    end
    
    graph
    |> Primitives.group(
      fn g ->
        g
        # Header background
        |> Primitives.rect(
          {@item_width, @menu_height},
          fill: bg_color,
          id: {:menu_header_bg, menu_id}
        )
        # Header text
        |> Primitives.text(
          label,
          fill: text_color,
          translate: {10, 20},
          font_size: 16,
          id: {:menu_header_text, menu_id}
        )
      end,
      translate: {x, y},
      id: {:menu_header, menu_id}
    )
  end
  
  defp render_all_dropdowns(graph, %State{dropdown_bounds: bounds} = state) do
    bounds
    |> Enum.reduce(graph, fn {menu_id, dropdown_bounds}, g ->
      render_dropdown(g, menu_id, dropdown_bounds, state)
    end)
  end
  
  defp render_dropdown(graph, menu_id, bounds, %State{menu_map: menu_map} = state) do
    {_label, items} = Map.get(menu_map, menu_id)
    
    # Only show if this menu is active
    hidden = state.active_menu != menu_id
    
    graph
    |> Primitives.group(
      fn g ->
        g
        # Dropdown background with shadow
        |> render_dropdown_shadow(bounds)
        |> Primitives.rect(
          {bounds.width, bounds.height},
          fill: state.theme.dropdown_bg,
          stroke: {1, :dark_gray},
          id: {:dropdown_bg, menu_id}
        )
        # Render each item
        |> render_dropdown_items(items, bounds, state)
      end,
      translate: {bounds.x, bounds.y},
      hidden: hidden,
      id: {:dropdown, menu_id}
    )
  end
  
  defp render_dropdown_shadow(graph, bounds) do
    # Simple shadow effect
    graph
    |> Primitives.rect(
      {bounds.width + 4, bounds.height + 4},
      fill: {:black, 64},
      translate: {2, 2}
    )
  end
  
  defp render_dropdown_items(graph, items, bounds, state) do
    items
    |> Enum.with_index()
    |> Enum.reduce(graph, fn {{item_id, label}, index}, g ->
      item_bounds = Map.get(bounds.items, item_id)
      render_dropdown_item(g, item_id, label, index, item_bounds, state)
    end)
  end
  
  defp render_dropdown_item(graph, item_id, label, index, item_bounds, state) do
    # Check if this item is hovered
    is_hovered = state.hovered_dropdown == item_id
    
    bg_color = if is_hovered do
      state.theme.dropdown_hover_bg
    else
      state.theme.dropdown_bg
    end
    
    text_color = if is_hovered do
      state.theme.dropdown_hover_text
    else
      state.theme.dropdown_text
    end
    
    # Item position relative to dropdown
    rel_x = 0
    rel_y = @dropdown_padding + (index * @dropdown_item_height)
    
    graph
    |> Primitives.group(
      fn g ->
        g
        # Item background
        |> Primitives.rect(
          {item_bounds.width - 10, @dropdown_item_height},
          fill: bg_color,
          translate: {5, rel_y},
          id: {:dropdown_item_bg, item_id}
        )
        # Item text
        |> Primitives.text(
          label,
          fill: text_color,
          translate: {15, rel_y + 20},
          font_size: 14,
          id: {:dropdown_item_text, item_id}
        )
      end,
      id: {:dropdown_item, item_id}
    )
  end
  
  defp add_semantic_data(graph, state) do
    # Add semantic data for testing
    semantic_data = %{
      type: :menu_bar,
      active_menu: state.active_menu,
      hovered_item: state.hovered_item,
      menu_structure: extract_menu_structure(state.menu_map)
    }
    
    graph
    |> Graph.modify(:menu_bar_background, fn primitive ->
      Map.put(primitive, :semantic, semantic_data)
    end)
  end
  
  defp extract_menu_structure(menu_map) do
    menu_map
    |> Enum.map(fn {menu_id, {label, items}} ->
      {menu_id, %{
        label: label,
        items: Enum.map(items, fn {item_id, item_label} ->
          %{id: item_id, label: item_label}
        end)
      }}
    end)
    |> Enum.into(%{})
  end
end