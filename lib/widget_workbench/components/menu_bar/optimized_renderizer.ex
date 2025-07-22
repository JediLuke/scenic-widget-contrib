defmodule WidgetWorkbench.Components.MenuBar.OptimizedRenderizer do
  @moduledoc """
  Optimized rendering logic for MenuBar that prevents flickering.
  
  Key optimizations:
  1. Pre-render all dropdowns with hidden visibility
  2. Update only changed elements instead of full re-render
  3. Use graph modifications instead of rebuilding
  4. Batch updates to minimize redraws
  """
  
  alias Scenic.Graph
  alias Scenic.Primitives
  alias WidgetWorkbench.Components.MenuBar.State
  
  @menu_height 40
  @item_width 150
  @dropdown_item_height 30
  @dropdown_padding 5
  
  @doc """
  Initial render - creates all elements with proper IDs for later updates.
  """
  def initial_render(graph, %State{} = state) do
    graph
    |> render_background(state)
    |> render_all_menu_headers(state)
    |> render_all_dropdowns_hidden(state)
    |> add_interaction_layer(state)
  end
  
  @doc """
  Optimized update - modifies only elements that changed.
  """
  def update_render(graph, %State{} = old_state, %State{} = new_state) do
    graph
    |> update_hover_states(old_state, new_state)
    |> update_active_dropdown(old_state, new_state)
    |> update_dropdown_hovers(old_state, new_state)
  end
  
  # Initial rendering functions
  
  defp render_background(graph, %State{frame: frame, theme: theme}) do
    graph
    |> Primitives.rect(
      {frame.size.width, @menu_height},
      fill: theme.background,
      translate: {frame.pin.x, frame.pin.y},
      id: :menubar_background
    )
  end
  
  defp render_all_menu_headers(graph, %State{menu_map: menu_map} = state) do
    menu_map
    |> Enum.with_index()
    |> Enum.reduce(graph, fn {{menu_id, {label, _items}}, index}, g ->
      render_menu_header(g, menu_id, label, index, state)
    end)
  end
  
  defp render_menu_header(graph, menu_id, label, index, %State{} = state) do
    x = state.frame.pin.x + (index * @item_width)
    y = state.frame.pin.y
    
    graph
    # Header background (for hover effect)
    |> Primitives.rect(
      {@item_width, @menu_height},
      fill: state.theme.background,
      translate: {x, y},
      id: {:menu_header_bg, menu_id}
    )
    # Header text
    |> Primitives.text(
      label,
      fill: Map.get(state.theme, :text, :white),
      translate: {x + 10, y + 26},
      id: {:menu_header_text, menu_id}
    )
    # Invisible hit target for mouse events
    |> Primitives.rect(
      {@item_width, @menu_height},
      fill: :transparent,
      translate: {x, y},
      id: {:menu_header_hit, menu_id}
    )
  end
  
  defp render_all_dropdowns_hidden(graph, %State{menu_map: menu_map} = state) do
    menu_map
    |> Enum.with_index()
    |> Enum.reduce(graph, fn {{menu_id, {_label, items}}, index}, g ->
      render_dropdown_hidden(g, menu_id, items, index, state)
    end)
  end
  
  defp render_dropdown_hidden(graph, menu_id, items, menu_index, %State{} = state) do
    x = state.frame.pin.x + (menu_index * @item_width)
    y = state.frame.pin.y + @menu_height
    
    dropdown_height = length(items) * @dropdown_item_height + (2 * @dropdown_padding)
    
    # Add the dropdown group to main graph, initially hidden
    graph
    |> Primitives.group(
      fn g ->
        g
        # Dropdown background
        |> Primitives.rect(
          {@item_width, dropdown_height},
          fill: state.theme.dropdown_bg,
          stroke: {1, Map.get(state.theme, :border, :gray)},
          id: {:dropdown_bg, menu_id}
        )
        # Dropdown items
        |> render_dropdown_items(menu_id, items, state)
      end,
      translate: {x, y},
      id: {:dropdown_group, menu_id},
      hidden: true  # Initially hidden
    )
  end
  
  defp render_dropdown_items(graph, menu_id, items, state) do
    items
    |> Enum.with_index()
    |> Enum.reduce(graph, fn {{item_id, label}, index}, g ->
      item_y = @dropdown_padding + (index * @dropdown_item_height)
      
      g
      # Item background (for hover)
      |> Primitives.rect(
        {@item_width - 2 * @dropdown_padding, @dropdown_item_height},
        fill: state.theme.dropdown_bg,
        translate: {@dropdown_padding, item_y},
        id: {:dropdown_item_bg, menu_id, item_id}
      )
      # Item text
      |> Primitives.text(
        label,
        fill: Map.get(state.theme, :dropdown_text, :black),
        translate: {@dropdown_padding + 10, item_y + 20},
        id: {:dropdown_item_text, menu_id, item_id}
      )
    end)
  end
  
  defp add_interaction_layer(graph, %State{frame: frame}) do
    # Add an invisible rect covering the menu area for capturing events
    graph
    |> Primitives.rect(
      {frame.size.width, @menu_height},
      fill: :transparent,
      translate: {frame.pin.x, frame.pin.y},
      id: :menubar_interaction_layer
    )
  end
  
  # Update functions - these modify existing elements
  
  defp update_hover_states(graph, old_state, new_state) do
    if old_state.hovered_item == new_state.hovered_item do
      graph  # No change needed
    else
      graph
      |> update_header_hover(old_state.hovered_item, false, new_state)
      |> update_header_hover(new_state.hovered_item, true, new_state)
    end
  end
  
  defp update_header_hover(graph, nil, _, _), do: graph
  defp update_header_hover(graph, menu_id, is_hovered, state) do
    Graph.modify(graph, {:menu_header_bg, menu_id}, fn primitive ->
      Scenic.Primitive.put_style(primitive, :fill,
        if(is_hovered, do: state.theme.hover_bg, else: state.theme.background)
      )
    end)
  end
  
  defp update_active_dropdown(graph, old_state, new_state) do
    if old_state.active_menu == new_state.active_menu do
      graph  # No change needed
    else
      graph
      |> hide_dropdown(old_state.active_menu)
      |> show_dropdown(new_state.active_menu)
    end
  end
  
  defp hide_dropdown(graph, nil), do: graph
  defp hide_dropdown(graph, menu_id) do
    Graph.modify(graph, {:dropdown_group, menu_id}, fn primitive ->
      Scenic.Primitive.put_style(primitive, :hidden, true)
    end)
  end
  
  defp show_dropdown(graph, nil), do: graph
  defp show_dropdown(graph, menu_id) do
    Graph.modify(graph, {:dropdown_group, menu_id}, fn primitive ->
      Scenic.Primitive.put_style(primitive, :hidden, false)
    end)
  end
  
  defp update_dropdown_hovers(graph, old_state, new_state) do
    if old_state.hovered_dropdown == new_state.hovered_dropdown do
      graph
    else
      graph
      |> update_dropdown_item_hover(old_state.hovered_dropdown, false, new_state)
      |> update_dropdown_item_hover(new_state.hovered_dropdown, true, new_state)
    end
  end
  
  defp update_dropdown_item_hover(graph, nil, _, _), do: graph
  defp update_dropdown_item_hover(graph, {menu_id, item_id}, is_hovered, state) do
    Graph.modify(graph, {:dropdown_item_bg, menu_id, item_id}, fn primitive ->
      Scenic.Primitive.put_style(primitive, :fill,
        if(is_hovered, do: state.theme.dropdown_hover_bg, else: state.theme.dropdown_bg)
      )
    end)
  end
end