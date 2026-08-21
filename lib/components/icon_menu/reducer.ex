defmodule ScenicWidgets.IconMenu.Reducer do
  @moduledoc """
  Pure state transition functions for IconMenu.

  Handles cursor movements, clicks, and keyboard input.
  """

  alias ScenicWidgets.IconMenu.State

  @doc """
  Process user input and return state transitions.

  Returns:
  - `{:noop, state}` - State unchanged or only visual state changed
  - `{:menu_item_clicked, item_id, state}` - Menu item was clicked
  """
  def process_input(%State{} = state, {:cursor_pos, coords}) do
    handle_cursor_pos(state, coords)
  end

  def process_input(
        %State{} = state,
        {:cursor_scroll, {{_dx, dy}, coords}}
      ) do
    scroll_open_select(state, dy, coords)
  end

  def process_input(%State{} = state, {:cursor_scroll, {_dx, dy, x, y}}) do
    scroll_open_select(state, dy, {x, y})
  end

  def process_input(%State{} = state, {:cursor_button, {:btn_left, 1, _mods, coords}}) do
    handle_click(state, coords)
  end

  def process_input(
        %State{dragging_slider: slider_id} = state,
        {:cursor_button, {:btn_left, 0, _mods, _coords}}
      )
      when not is_nil(slider_id) do
    {:noop, %{state | dragging_slider: nil}}
  end

  def process_input(%State{} = state, {:key, {:key_esc, key_state, _mods}})
      when key_state > 0 do
    handle_escape(state)
  end

  def process_input(state, _input) do
    {:noop, state}
  end

  @doc """
  Handle cursor position for hover effects.
  """
  def handle_cursor_pos(%State{} = state, coords) do
    if state.dragging_slider do
      update_slider(state, state.dragging_slider, coords, true)
    else
      do_handle_cursor_pos(state, coords)
    end
  end

  defp do_handle_cursor_pos(%State{} = state, coords) do
    cond do
      # Check if cursor is over icon buttons
      State.point_in_icon_bar?(state, coords) ->
        hovered_icon = State.find_hovered_icon(state, coords)

        new_state = %{state | hovered_menu: hovered_icon, hovered_item: nil}

        # If a dropdown is open and we hover a different icon, switch to it
        new_state =
          if state.active_menu && hovered_icon && state.active_menu != hovered_icon do
            %{new_state | active_menu: hovered_icon}
          else
            new_state
          end

        {:noop, new_state}

      # Check if cursor is in dropdown
      state.active_menu != nil ->
        case State.point_in_dropdown?(state, coords) do
          {true, item_id} ->
            # Inside dropdown, possibly over an item
            {:noop, %{state | hovered_item: item_id, hovered_menu: state.active_menu}}

          {false, _} ->
            # Pointer motion alone never dismisses an open menu. This avoids
            # stale/out-of-order cursor samples closing a menu immediately
            # after a semantic or real click; click-away and Escape remain the
            # authoritative dismissal gestures.
            {:noop, %{state | hovered_item: nil}}
        end

      # Cursor outside menu area
      true ->
        if state.hovered_menu do
          {:noop, %{state | hovered_menu: nil, hovered_item: nil}}
        else
          {:noop, state}
        end
    end
  end

  @doc """
  Handle click events.
  """
  def handle_click(%State{} = state, coords) do
    cond do
      # Click on icon button
      State.point_in_icon_bar?(state, coords) ->
        case State.find_hovered_icon(state, coords) do
          nil ->
            {:noop, state}

          menu_id ->
            if state.active_menu == menu_id do
              # Click on active menu - close it
              {:noop,
               recalculate(%{
                 state
                 | active_menu: nil,
                   hovered_menu: nil,
                   hovered_item: nil,
                   dropdown_scroll: 0
               })}
            else
              # Open this menu. A dropdown always opens at its top: reopening
              # one where the last visit left it would hide the first rows.
              {:noop,
               recalculate(%{state | active_menu: menu_id, hovered_item: nil, dropdown_scroll: 0})}
            end
        end

      # Click in dropdown
      state.active_menu != nil ->
        case State.point_in_dropdown?(state, coords) do
          {true, nil} ->
            # Click in dropdown but not on an item
            {:noop, state}

          {true, item_id} ->
            # Click on menu item
            item = State.find_item(state, item_id)

            if item && not State.item_enabled?(item) do
              {:noop, state}
            else
              activate_item(state, item, item_id, coords)
            end

          {false, _} ->
            # Click outside dropdown - close menu
            {:noop, %{state | active_menu: nil, hovered_menu: nil, hovered_item: nil}}
        end

      # Click outside menu area
      true ->
        {:noop, state}
    end
  end

  defp activate_item(state, %ScenicWidgets.Menu.Model.Slider{}, item_id, {x, _y}) do
    update_slider(state, item_id, {x, 0}, true)
  end

  # A tree row: the header opens and shuts it, and inside it the TRIANGLE
  # expands a branch while the rest of the row ticks it. Two intentions, two
  # targets — one rectangle carrying both means the commonest thing you want
  # from a tree ("not that one") cannot be done to anything with children.
  defp activate_item(state, %ScenicWidgets.Menu.Model.Tree{} = tree, item_id, {x, y}) do
    bounds = state.dropdown_bounds[state.active_menu].items[item_id]
    row_height = state.theme.dropdown_item_height

    if tree.expanded? and y >= bounds.y + row_height do
      index = tree.scroll_offset + floor((y - bounds.y - row_height) / row_height)

      case Enum.at(ScenicWidgets.Menu.Model.visible_tree_nodes(tree), index) do
        nil ->
          {:noop, state}

        {node, depth} ->
          gutter = 8 + depth * ScenicWidgets.Menu.Model.tree_indent()

          cond do
            node.children != [] and x >= gutter and x < gutter + ScenicWidgets.Menu.Model.tree_indent() ->
              {:noop, replace_and_recalculate(state, item_id,
                ScenicWidgets.Menu.Model.toggle_tree_expanded(tree, node.id))}

            true ->
              updated = ScenicWidgets.Menu.Model.toggle_tree_node(tree, node.id)

              {:menu_tree_changed, item_id, {node.id, not node.checked?},
               replace_and_recalculate(state, item_id, updated)}
          end
      end
    else
      {:noop,
       replace_and_recalculate(state, item_id, %{tree | expanded?: not tree.expanded?})}
    end
  end

  defp activate_item(state, %ScenicWidgets.Menu.Model.Select{} = select, item_id, {_x, y}) do
    bounds = state.dropdown_bounds[state.active_menu].items[item_id]
    row_height = state.theme.dropdown_item_height

    if select.expanded? and y >= bounds.y + row_height do
      visible_index = floor((y - bounds.y - row_height) / row_height)
      option = Enum.at(select.options, select.scroll_offset + visible_index)

      if is_nil(option) do
        {:noop, state}
      else
        updated = %{select | value: option, expanded?: false}
        {:menu_value_changed, item_id, option, replace_and_recalculate(state, item_id, updated)}
      end
    else
      updated = %{select | expanded?: not select.expanded?}
      {:noop, replace_and_recalculate(state, item_id, updated)}
    end
  end

  # A wheel inside an open dropdown belongs to whichever thing is scrollable
  # there: an expanded Select if the pointer is on one, otherwise the dropdown
  # itself when it is taller than the room beneath the menu bar.
  defp scroll_open_select(state, dy, coords) do
    case State.point_in_dropdown?(state, coords) do
      {true, item_id} ->
        case State.find_item(state, item_id) do
          %ScenicWidgets.Menu.Model.Tree{expanded?: true} = tree ->
            max_offset =
              max(0, ScenicWidgets.Menu.Model.tree_node_count(tree) - tree.max_visible)

            direction = if dy > 0, do: 1, else: -1
            offset = min(max_offset, max(0, tree.scroll_offset + direction))
            {:noop, replace_and_recalculate(state, item_id, %{tree | scroll_offset: offset})}

          %ScenicWidgets.Menu.Model.Select{expanded?: true} = select ->
            max_offset = max(0, length(select.options) - 4)
            direction = if dy > 0, do: 1, else: -1
            offset = min(max_offset, max(0, select.scroll_offset + direction))
            updated = %{select | scroll_offset: offset}
            {:noop, replace_and_recalculate(state, item_id, updated)}

          _ ->
            {:noop, scroll_dropdown(state, dy)}
        end

      # The wheel somewhere else: the person has finished with the menu and
      # started reading what is behind it. A dropdown left hanging over that
      # is in the way.
      _ ->
        {:noop, %{state | active_menu: nil, hovered_item: nil}}
    end
  end

  @dropdown_scroll_step 40

  defp scroll_dropdown(state, dy) do
    max_scroll = State.max_dropdown_scroll(state)

    if max_scroll == 0 do
      state
    else
      step = if dy > 0, do: -@dropdown_scroll_step, else: @dropdown_scroll_step
      scrolled = min(max(state.dropdown_scroll + step, 0), max_scroll)
      recalculate(%{state | dropdown_scroll: scrolled})
    end
  end

  defp activate_item(state, %ScenicWidgets.Menu.Model.Stepper{} = stepper, item_id, {x, _y}) do
    bounds = state.dropdown_bounds[state.active_menu].items[item_id]
    local_x = x - bounds.x

    delta =
      cond do
        local_x >= bounds.width - 40 -> stepper.step
        local_x >= bounds.width - 128 and local_x <= bounds.width - 92 -> -stepper.step
        true -> 0
      end

    if delta == 0 do
      {:noop, state}
    else
      value = min(stepper.max, max(stepper.min, stepper.value + delta))
      updated = %{stepper | value: value}
      {:menu_value_changed, item_id, value, replace_and_recalculate(state, item_id, updated)}
    end
  end

  defp activate_item(
         state,
         %ScenicWidgets.Menu.Model.Toggle{checked?: checked} = toggle,
         item_id,
         _coords
       ) do
    updated = %{toggle | checked?: not checked}
    menus = replace_active_item(state, item_id, updated)

    {:menu_value_changed, item_id, updated.checked?,
     %{state | menus: menus, hovered_item: item_id}}
  end

  defp activate_item(state, _item, item_id, _coords) do
    # Execute action callback if present
    action = State.get_item_action(state, item_id)
    if is_function(action, 0), do: action.()

    # Close menu and notify parent
    new_state = %{
      state
      | active_menu: nil,
        hovered_menu: nil,
        hovered_item: nil,
        dragging_slider: nil
    }

    {:menu_item_clicked, item_id, new_state}
  end

  defp update_slider(state, item_id, {x, _y}, dragging?) do
    slider = State.find_item(state, item_id)
    bounds = state.dropdown_bounds[state.active_menu].items[item_id]
    track_inset = 10
    ratio = (x - bounds.x - track_inset) / max(bounds.width - 2 * track_inset, 1)
    raw = slider.min + min(1.0, max(0.0, ratio)) * (slider.max - slider.min)
    steps = round((raw - slider.min) / slider.step)
    value = min(slider.max, max(slider.min, slider.min + steps * slider.step))
    updated = %{slider | value: value}

    menus = replace_active_item(state, item_id, updated)

    new_state = %{
      state
      | menus: menus,
        hovered_item: item_id,
        dragging_slider: if(dragging?, do: item_id, else: state.dragging_slider)
    }

    {:menu_value_changed, item_id, value, new_state}
  end

  defp replace_active_item(state, item_id, updated) do
    Enum.map(state.menus, fn
      %{id: id, items: items} = menu when id == state.active_menu ->
        %{
          menu
          | items: Enum.map(items, &if(State.get_item_id(&1) == item_id, do: updated, else: &1))
        }

      menu ->
        menu
    end)
  end

  defp recalculate(state), do: %{state | dropdown_bounds: State.calculate_dropdown_bounds(state)}

  defp replace_and_recalculate(state, item_id, updated) do
    state = %{state | menus: replace_active_item(state, item_id, updated), hovered_item: item_id}
    %{state | dropdown_bounds: State.calculate_dropdown_bounds(state)}
  end

  @doc """
  Handle escape key to close menus.
  """
  def handle_escape(%State{active_menu: nil} = state) do
    {:noop, state}
  end

  def handle_escape(%State{} = state) do
    {:noop,
     %{state | active_menu: nil, hovered_menu: nil, hovered_item: nil, dragging_slider: nil}}
  end
end
