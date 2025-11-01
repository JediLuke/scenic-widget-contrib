defmodule ScenicWidgets.MenuBar.OptimizedRenderizer do
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
  alias ScenicWidgets.MenuBar.State
  
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
    |> update_interaction_layer(old_state, new_state)
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
    # Use relative positioning starting from 0,0
    x = index * @item_width
    y = 0
    
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
      font: :roboto_mono,
      translate: {x + 10, y + 26},
      id: {:menu_header_text, menu_id}
    )
    # Hit target for mouse events - captures input for hover and clicks
    |> Primitives.rect(
      {@item_width, @menu_height},
      fill: :transparent,
      translate: {x, y},
      id: {:menu_header_hit, menu_id},
      input: [:cursor_pos, :cursor_button]
    )
  end
  
  defp render_all_dropdowns_hidden(graph, %State{menu_map: menu_map} = state) do
    menu_map
    |> Enum.with_index()
    |> Enum.reduce(graph, fn {{menu_id, {_label, items}}, index}, g ->
      g
      |> render_dropdown_hidden(menu_id, items, index, state)
      |> render_all_sub_menus_hidden(menu_id, items, index, state)
    end)
  end
  
  defp render_dropdown_hidden(graph, menu_id, items, menu_index, %State{} = state) do
    # Use relative positioning
    x = menu_index * @item_width
    y = @menu_height
    
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
    |> Enum.reduce(graph, fn {item, index}, g ->
      item_y = @dropdown_padding + (index * @dropdown_item_height)
      
      case item do
        {item_id, label, _action} when is_binary(item_id) ->
          # Regular menu item with action callback (3-tuple format)
          g
          # Item background (for hover) - captures input for interaction
          |> Primitives.rect(
            {@item_width - 2 * @dropdown_padding, @dropdown_item_height},
            fill: state.theme.dropdown_bg,
            translate: {@dropdown_padding, item_y},
            id: {:dropdown_item_bg, menu_id, item_id},
            input: [:cursor_pos, :cursor_button]
          )
          # Item text
          |> Primitives.text(
            label,
            fill: Map.get(state.theme, :dropdown_text, :black),
            font: :roboto_mono,
            translate: {@dropdown_padding + 10, item_y + 20},
            id: {:dropdown_item_text, menu_id, item_id}
          )

        {item_id, label} when is_binary(item_id) ->
          # Regular menu item (2-tuple format)
          g
          # Item background (for hover) - captures input for interaction
          |> Primitives.rect(
            {@item_width - 2 * @dropdown_padding, @dropdown_item_height},
            fill: state.theme.dropdown_bg,
            translate: {@dropdown_padding, item_y},
            id: {:dropdown_item_bg, menu_id, item_id},
            input: [:cursor_pos, :cursor_button]
          )
          # Item text
          |> Primitives.text(
            label,
            fill: Map.get(state.theme, :dropdown_text, :black),
            font: :roboto_mono,
            translate: {@dropdown_padding + 10, item_y + 20},
            id: {:dropdown_item_text, menu_id, item_id}
          )
        
        {:sub_menu, label, _sub_items} ->
          # Sub-menu item with arrow indicator
          sub_menu_id = "submenu_#{String.downcase(String.replace(label, " ", "_"))}"
          g
          # Item background (for hover)
          |> Primitives.rect(
            {@item_width - 2 * @dropdown_padding, @dropdown_item_height},
            fill: state.theme.dropdown_bg,
            translate: {@dropdown_padding, item_y},
            id: {:dropdown_item_bg, menu_id, sub_menu_id},
            input: [:cursor_pos, :cursor_button]
          )
          # Item text
          |> Primitives.text(
            label,
            fill: Map.get(state.theme, :dropdown_text, :black),
            font: :roboto_mono,
            translate: {@dropdown_padding + 10, item_y + 20},
            id: {:dropdown_item_text, menu_id, sub_menu_id}
          )
          # Arrow indicator - draw a triangle instead of using text
          |> Primitives.triangle(
            {{@item_width - @dropdown_padding - 20, item_y + 10},
             {@item_width - @dropdown_padding - 20, item_y + 25},
             {@item_width - @dropdown_padding - 10, item_y + 17.5}},
            fill: Map.get(state.theme, :dropdown_text, :black),
            id: {:dropdown_item_arrow, menu_id, sub_menu_id}
          )
      end
    end)
  end
  
  defp render_all_sub_menus_hidden(graph, menu_id, items, menu_index, state) do
    items
    |> Enum.with_index()
    |> Enum.reduce(graph, fn {item, item_index}, g ->
      case item do
        {:sub_menu, label, sub_items} ->
          sub_menu_id = "submenu_#{String.downcase(String.replace(label, " ", "_"))}"
          parent_x = menu_index * @item_width
          parent_y = @menu_height + @dropdown_padding + (item_index * @dropdown_item_height)
          
          render_sub_menu_hidden(g, sub_menu_id, sub_items, parent_x, parent_y, state)
        _ ->
          g
      end
    end)
  end
  
  defp render_sub_menu_hidden(graph, sub_menu_id, items, parent_x, parent_y, state) do
    # Position sub-menu to the right of parent item
    x = parent_x + @item_width - @dropdown_padding
    y = parent_y

    dropdown_height = length(items) * @dropdown_item_height + (2 * @dropdown_padding)

    # Add the sub-menu dropdown group, initially hidden
    graph = graph
    |> Primitives.group(
      fn g ->
        g
        # Sub-dropdown background
        |> Primitives.rect(
          {@item_width, dropdown_height},
          fill: state.theme.dropdown_bg,
          stroke: {1, Map.get(state.theme, :border, :gray)},
          id: {:sub_dropdown_bg, sub_menu_id}
        )
        # Sub-dropdown items
        |> render_sub_dropdown_items(sub_menu_id, items, state)
      end,
      translate: {x, y},
      id: {:sub_dropdown_group, sub_menu_id},
      hidden: true  # Initially hidden
    )

    # Recursively render any nested sub-menus within these items
    render_nested_sub_menus_hidden(graph, items, x, y, state)
  end

  defp render_nested_sub_menus_hidden(graph, items, parent_x, parent_y, state) do
    items
    |> Enum.with_index()
    |> Enum.reduce(graph, fn {item, item_index}, g ->
      case item do
        {:sub_menu, label, sub_items} ->
          sub_menu_id = "submenu_#{String.downcase(String.replace(label, " ", "_"))}"
          item_y = parent_y + @dropdown_padding + (item_index * @dropdown_item_height)

          # Recursively render this nested sub-menu
          render_sub_menu_hidden(g, sub_menu_id, sub_items, parent_x, item_y, state)
        _ ->
          g
      end
    end)
  end
  
  defp add_interaction_layer(graph, %State{frame: frame, active_menu: active_menu, menu_map: menu_map}) do
    # Calculate height based on whether a dropdown is open
    height = if active_menu do
      # Get the items for the active menu
      case Map.get(menu_map, active_menu) do
        {_label, items} ->
          dropdown_height = length(items) * @dropdown_item_height + (2 * @dropdown_padding)
          @menu_height + dropdown_height
        _ ->
          frame.size.height
      end
    else
      frame.size.height
    end
    
    require Logger
    Logger.debug("MenuBar interaction layer: translate={0, 0}, size={#{frame.size.width}, #{height}}")
    
    # Don't capture input - let the parent handle all input routing
    graph
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
    if old_state.active_menu == new_state.active_menu &&
       old_state.active_sub_menus == new_state.active_sub_menus do
      graph  # No change needed
    else
      graph
      |> hide_dropdown(old_state.active_menu)
      |> show_dropdown(new_state.active_menu)
      |> update_sub_menus(old_state, new_state)
    end
  end
  
  defp hide_dropdown(graph, nil), do: graph
  defp hide_dropdown(graph, menu_id) do
    graph
    |> Graph.modify({:dropdown_group, menu_id}, fn primitive ->
      Scenic.Primitive.put_style(primitive, :hidden, true)
    end)
    |> hide_all_sub_menus_for_menu(menu_id)
  end
  
  defp hide_all_sub_menus_for_menu(graph, menu_id) do
    # Hide all sub-menus that belong to this menu
    # This prevents orphaned sub-menus when the parent closes
    graph
    |> Graph.reduce(graph, fn
      {id, primitive}, acc when is_tuple(id) ->
        case id do
          {:sub_menu_group, ^menu_id, _sub_id} ->
            # This is a sub-menu for our menu, hide it
            Graph.modify(acc, id, fn p ->
              Scenic.Primitive.put_style(p, :hidden, true)
            end)
          _ ->
            acc
        end
      _, acc ->
        acc
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
  defp update_dropdown_item_hover(graph, item_id, is_hovered, state) when is_atom(item_id) do
    # Handle case where just item_id is passed (need to get menu_id from state)
    if state.active_menu do
      update_dropdown_item_hover(graph, {state.active_menu, item_id}, is_hovered, state)
    else
      graph
    end
  end
  defp update_dropdown_item_hover(graph, {parent_id, item_id}, is_hovered, state) do
    require Logger
    # Try both regular dropdown items and sub-menu items
    # For regular dropdowns, use :dropdown_item_bg
    # For sub-menus, use :sub_dropdown_item_bg

    # Check if parent_id is the active menu (regular dropdown) or a sub-menu
    id_prefix = if parent_id == state.active_menu do
      :dropdown_item_bg
    else
      :sub_dropdown_item_bg
    end

    Logger.debug("Updating hover for {#{inspect(id_prefix)}, #{inspect(parent_id)}, #{inspect(item_id)}} - hovered: #{is_hovered}")

    try do
      Graph.modify(graph, {id_prefix, parent_id, item_id}, fn primitive ->
        Scenic.Primitive.put_style(primitive, :fill,
          if(is_hovered, do: state.theme.dropdown_hover_bg, else: state.theme.dropdown_bg)
        )
      end)
    rescue
      e ->
        Logger.warning("Failed to update hover for {#{inspect(id_prefix)}, #{inspect(parent_id)}, #{inspect(item_id)}}: #{inspect(e)}")
        graph
    end
  end
  
  defp update_interaction_layer(graph, old_state, new_state) do
    if old_state.active_menu == new_state.active_menu do
      graph  # No change needed
    else
      # Calculate new height
      height = if new_state.active_menu do
        case Map.get(new_state.menu_map, new_state.active_menu) do
          {_label, items} ->
            dropdown_height = length(items) * @dropdown_item_height + (2 * @dropdown_padding)
            @menu_height + dropdown_height
          _ ->
            new_state.frame.size.height
        end
      else
        new_state.frame.size.height
      end
      
      # Update the interaction layer size
      Graph.modify(graph, :menubar_interaction_layer, fn primitive ->
        {width, _old_height} = primitive.data
        Scenic.Primitive.put(primitive, {width, height})
      end)
    end
  end
  
  # Sub-menu update functions
  
  defp update_sub_menus(graph, old_state, new_state) do
    # Hide old sub-menus that are no longer active OR have changed values
    old_sub_menus = Map.keys(old_state.active_sub_menus)
    new_sub_menus = Map.keys(new_state.active_sub_menus)

    # Find keys that were removed
    removed_keys = old_sub_menus -- new_sub_menus

    # Find keys that exist in both but have different values (sibling switch)
    changed_keys = Enum.filter(old_sub_menus, fn key ->
      key in new_sub_menus &&
      Map.get(old_state.active_sub_menus, key) != Map.get(new_state.active_sub_menus, key)
    end)

    # Find keys that were added
    added_keys = new_sub_menus -- old_sub_menus

    # Hide removed sub-menus and old values of changed sub-menus
    graph = Enum.reduce(removed_keys ++ changed_keys, graph, fn menu_id, g ->
      case Map.get(old_state.active_sub_menus, menu_id) do
        nil -> g
        sub_menu_id -> hide_sub_menu(g, menu_id, sub_menu_id)
      end
    end)

    # Show new sub-menus and new values of changed sub-menus
    Enum.reduce(added_keys ++ changed_keys, graph, fn menu_id, g ->
      case Map.get(new_state.active_sub_menus, menu_id) do
        nil -> g
        sub_menu_id -> show_sub_menu(g, menu_id, sub_menu_id, new_state)
      end
    end)
  end
  
  defp hide_sub_menu(graph, _menu_id, sub_menu_id) do
    require Logger
    Logger.debug("Hiding sub-menu: #{inspect(sub_menu_id)}")

    # Hide this sub-menu
    graph = try do
      Graph.modify(graph, {:sub_dropdown_group, sub_menu_id}, fn primitive ->
        Scenic.Primitive.put_style(primitive, :hidden, true)
      end)
    rescue
      _ -> graph  # Sub-menu might not exist yet
    end

    # Also recursively hide any nested sub-menus within this one
    # This prevents orphaned menus when switching siblings
    hide_all_nested_sub_menus(graph, sub_menu_id)
  end

  defp hide_all_nested_sub_menus(graph, _parent_sub_menu_id) do
    # Hide all sub-dropdown groups recursively
    # This is a brute-force approach: hide ALL sub-dropdowns
    # A more sophisticated approach would track the hierarchy

    Graph.reduce(graph, graph, fn
      {{:sub_dropdown_group, _id}, _primitive}, acc ->
        # Try to hide this sub-dropdown
        try do
          Graph.modify(acc, {:sub_dropdown_group, _id}, fn p ->
            Scenic.Primitive.put_style(p, :hidden, true)
          end)
        rescue
          _ -> acc
        end
      _, acc ->
        acc
    end)
  end
  
  defp show_sub_menu(graph, menu_id, sub_menu_id, state) do
    # First ensure the sub-menu is rendered
    graph = ensure_sub_menu_rendered(graph, menu_id, sub_menu_id, state)
    
    # Then show it
    Graph.modify(graph, {:sub_dropdown_group, sub_menu_id}, fn primitive ->
      Scenic.Primitive.put_style(primitive, :hidden, false)
    end)
  end
  
  defp ensure_sub_menu_rendered(graph, menu_id, sub_menu_id, state) do
    # Check if sub-menu already exists in graph
    case Graph.get(graph, {:sub_dropdown_group, sub_menu_id}) do
      nil ->
        # Need to render the sub-menu
        render_sub_menu(graph, menu_id, sub_menu_id, state)
      _ ->
        # Already rendered
        graph
    end
  end
  
  defp render_sub_menu(graph, menu_id, sub_menu_id, state) do
    # Find the sub-menu data
    case find_sub_menu_data(state.menu_map, menu_id, sub_menu_id) do
      nil -> 
        graph
      {sub_menu_items, parent_bounds} ->
        # Calculate position relative to parent item
        x = parent_bounds.x + parent_bounds.width - @dropdown_padding
        y = parent_bounds.y
        
        dropdown_height = length(sub_menu_items) * @dropdown_item_height + (2 * @dropdown_padding)
        
        # Add the sub-menu dropdown
        graph
        |> Primitives.group(
          fn g ->
            g
            # Sub-dropdown background
            |> Primitives.rect(
              {@item_width, dropdown_height},
              fill: state.theme.dropdown_bg,
              stroke: {1, Map.get(state.theme, :border, :gray)},
              id: {:sub_dropdown_bg, sub_menu_id}
            )
            # Sub-dropdown items
            |> render_sub_dropdown_items(sub_menu_id, sub_menu_items, state)
          end,
          translate: {x, y},
          id: {:sub_dropdown_group, sub_menu_id},
          hidden: false  # Show immediately
        )
    end
  end
  
  defp find_sub_menu_data(menu_map, menu_id, sub_menu_id) do
    case Map.get(menu_map, menu_id) do
      {_label, items} ->
        # First check direct children
        case find_sub_menu_in_items(items, sub_menu_id) do
          {item_index, sub_items} ->
            # Found as direct child - calculate bounds
            menu_index = menu_map |> Map.keys() |> Enum.find_index(&(&1 == menu_id))
            parent_x = (menu_index || 0) * @item_width
            parent_y = @menu_height + @dropdown_padding + (item_index * @dropdown_item_height)

            bounds = %{
              x: parent_x,
              y: parent_y,
              width: @item_width,
              height: @dropdown_item_height
            }
            {sub_items, bounds}

          nil ->
            # Not a direct child - search recursively in nested sub-menus
            find_nested_sub_menu_data(items, sub_menu_id, 0, @menu_height)
        end
      _ ->
        nil
    end
  end

  # Find a sub-menu in a flat list of items (direct children only)
  defp find_sub_menu_in_items(items, target_id) do
    items
    |> Enum.with_index()
    |> Enum.find_value(fn {item, index} ->
      case item do
        {:sub_menu, label, sub_items} ->
          item_id = "submenu_#{String.downcase(String.replace(label, " ", "_"))}"
          if item_id == target_id do
            {index, sub_items}
          end
        _ ->
          nil
      end
    end)
  end

  # Recursively search for sub-menu in nested structure
  defp find_nested_sub_menu_data(items, target_id, base_x, base_y) do
    items
    |> Enum.with_index()
    |> Enum.find_value(fn {item, index} ->
      case item do
        {:sub_menu, label, sub_items} ->
          item_id = "submenu_#{String.downcase(String.replace(label, " ", "_"))}"
          item_y = base_y + @dropdown_padding + (index * @dropdown_item_height)

          if item_id == target_id do
            # Found it!
            bounds = %{
              x: base_x,
              y: item_y,
              width: @item_width,
              height: @dropdown_item_height
            }
            {sub_items, bounds}
          else
            # Not this one, search deeper
            next_x = base_x + @item_width - @dropdown_padding
            find_nested_sub_menu_data(sub_items, target_id, next_x, item_y)
          end
        _ ->
          nil
      end
    end)
  end
  
  defp render_sub_dropdown_items(graph, sub_menu_id, items, state) do
    items
    |> Enum.with_index()
    |> Enum.reduce(graph, fn {item, index}, g ->
      item_y = @dropdown_padding + (index * @dropdown_item_height)
      
      case item do
        {item_id, label, _action} when is_binary(item_id) ->
          # Regular sub-menu item with action callback (3-tuple format)
          g
          # Item background (for hover)
          |> Primitives.rect(
            {@item_width - 2 * @dropdown_padding, @dropdown_item_height},
            fill: state.theme.dropdown_bg,
            translate: {@dropdown_padding, item_y},
            id: {:sub_dropdown_item_bg, sub_menu_id, item_id},
            input: [:cursor_pos, :cursor_button]
          )
          # Item text
          |> Primitives.text(
            label,
            fill: Map.get(state.theme, :dropdown_text, :black),
            font: :roboto_mono,
            translate: {@dropdown_padding + 10, item_y + 20},
            id: {:sub_dropdown_item_text, sub_menu_id, item_id}
          )

        {item_id, label} when is_binary(item_id) ->
          # Regular sub-menu item (2-tuple format)
          g
          # Item background (for hover)
          |> Primitives.rect(
            {@item_width - 2 * @dropdown_padding, @dropdown_item_height},
            fill: state.theme.dropdown_bg,
            translate: {@dropdown_padding, item_y},
            id: {:sub_dropdown_item_bg, sub_menu_id, item_id},
            input: [:cursor_pos, :cursor_button]
          )
          # Item text
          |> Primitives.text(
            label,
            fill: Map.get(state.theme, :dropdown_text, :black),
            font: :roboto_mono,
            translate: {@dropdown_padding + 10, item_y + 20},
            id: {:sub_dropdown_item_text, sub_menu_id, item_id}
          )
          
        {:sub_menu, label, _sub_sub_items} ->
          # Sub-sub-menu item (with arrow)
          sub_sub_menu_id = "submenu_#{String.downcase(String.replace(label, " ", "_"))}"
          g
          # Item background (for hover)
          |> Primitives.rect(
            {@item_width - 2 * @dropdown_padding, @dropdown_item_height},
            fill: state.theme.dropdown_bg,
            translate: {@dropdown_padding, item_y},
            id: {:sub_dropdown_item_bg, sub_menu_id, sub_sub_menu_id},
            input: [:cursor_pos, :cursor_button]
          )
          # Item text
          |> Primitives.text(
            label,
            fill: Map.get(state.theme, :dropdown_text, :black),
            font: :roboto_mono,
            translate: {@dropdown_padding + 10, item_y + 20},
            id: {:sub_dropdown_item_text, sub_menu_id, sub_sub_menu_id}
          )
          # Arrow indicator - draw a triangle (pointing right)
          |> Primitives.triangle(
            {{@item_width - @dropdown_padding - 20, item_y + 10},
             {@item_width - @dropdown_padding - 20, item_y + 25},
             {@item_width - @dropdown_padding - 10, item_y + 17.5}},
            fill: Map.get(state.theme, :dropdown_text, :black),
            id: {:sub_dropdown_item_arrow, sub_menu_id, sub_sub_menu_id}
          )
      end
    end)
  end
end