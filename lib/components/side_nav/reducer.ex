defmodule ScenicWidgets.SideNav.Reducer do
  @moduledoc """
  State reduction logic for the SideNav component.
  Handles all user input and state transitions following HexDocs behavior:

  - Click chevron: toggle expand/collapse
  - Click text: emit navigation event (no expand/collapse)
  - Keyboard navigation: Up/Down/Left/Right/Enter
  - Auto-scroll to keep focused item visible
  """

  alias ScenicWidgets.SideNav.{State, Item}

  @doc """
  Handle mouse click input.
  Returns {:navigate, item_id, new_state} or {:noop, new_state}
  """
  def handle_click(%State{} = state, coords) do
    case State.hit_test(state, coords) do
      {item_id, :chevron} ->
        # Chevron clicked - toggle expansion
        new_state = State.toggle_expanded(state, item_id)
        {:noop, new_state}

      {item_id, :text} ->
        # Text clicked - set active and emit navigation event
        new_state = state
        |> State.set_active(item_id)
        |> State.set_focused(item_id)

        {:navigate, item_id, new_state}

      nil ->
        # Click outside any item
        {:noop, state}
    end
  end

  @doc """
  Handle cursor position for hover effects.
  Returns updated state with hover information.
  """
  def handle_cursor_pos(%State{} = state, coords) do
    # For now, just store which item is hovered
    # The renderizer will use this for hover highlighting
    case State.hit_test(state, coords) do
      {item_id, _region} ->
        Map.put(state, :hovered_id, item_id)

      nil ->
        Map.put(state, :hovered_id, nil)
    end
  end

  @doc """
  Handle Down arrow key - move focus to next visible item.
  """
  def handle_key_down(%State{} = state) do
    current = state.focused_id || state.active_id

    if current do
      case State.next_item(state, current) do
        nil -> state  # Already at last item
        next_id ->
          new_state = State.set_focused(state, next_id)
          auto_scroll_to_item(new_state, next_id)
      end
    else
      # No focus yet, focus first visible item
      case State.visible_items(state) |> List.first() do
        nil -> state
        first_id ->
          State.set_focused(state, first_id)
      end
    end
  end

  @doc """
  Handle Up arrow key - move focus to previous visible item.
  """
  def handle_key_up(%State{} = state) do
    current = state.focused_id || state.active_id

    if current do
      case State.prev_item(state, current) do
        nil -> state  # Already at first item
        prev_id ->
          new_state = State.set_focused(state, prev_id)
          auto_scroll_to_item(new_state, prev_id)
      end
    else
      # No focus yet, focus first visible item
      case State.visible_items(state) |> List.first() do
        nil -> state
        first_id ->
          State.set_focused(state, first_id)
      end
    end
  end

  @doc """
  Handle Right arrow key:
  - If focused item is collapsed with children: expand it
  - If focused item is expanded with children: move to first child
  - Otherwise: no-op
  """
  def handle_key_right(%State{} = state) do
    current = state.focused_id || state.active_id

    if current do
      item = Item.find_by_id(state.tree, current)

      if Item.has_children?(item) do
        if MapSet.member?(state.expanded, current) do
          # Already expanded, move to first child
          children = Item.get_children(item)
          if length(children) > 0 do
            first_child_id = Item.get_id(List.first(children))
            new_state = State.set_focused(state, first_child_id)
            auto_scroll_to_item(new_state, first_child_id)
          else
            state
          end
        else
          # Collapsed, expand it
          State.expand(state, current)
        end
      else
        # No children, no-op
        state
      end
    else
      state
    end
  end

  @doc """
  Handle Left arrow key:
  - If focused item is expanded: collapse it
  - If focused item is collapsed or has no children: move to parent
  """
  def handle_key_left(%State{} = state) do
    current = state.focused_id || state.active_id

    if current do
      item = Item.find_by_id(state.tree, current)

      if Item.has_children?(item) && MapSet.member?(state.expanded, current) do
        # Expanded with children, collapse it
        State.collapse(state, current)
      else
        # Move to parent
        case find_parent(state.tree, current) do
          nil -> state  # Already at root level
          parent_id ->
            new_state = State.set_focused(state, parent_id)
            auto_scroll_to_item(new_state, parent_id)
        end
      end
    else
      state
    end
  end

  @doc """
  Handle Enter key - emit navigation event for focused item.
  Returns {:navigate, item_id, new_state}
  """
  def handle_key_enter(%State{} = state) do
    current = state.focused_id || state.active_id

    if current do
      new_state = State.set_active(state, current)
      {:navigate, current, new_state}
    else
      {:noop, state}
    end
  end

  @doc """
  Handle Home key - jump to first visible item.
  """
  def handle_key_home(%State{} = state) do
    case State.visible_items(state) |> List.first() do
      nil -> state
      first_id ->
        new_state = State.set_focused(state, first_id)
        auto_scroll_to_item(new_state, first_id)
    end
  end

  @doc """
  Handle End key - jump to last visible item.
  """
  def handle_key_end(%State{} = state) do
    case State.visible_items(state) |> List.last() do
      nil -> state
      last_id ->
        new_state = State.set_focused(state, last_id)
        auto_scroll_to_item(new_state, last_id)
    end
  end

  @doc """
  Handle Escape key - clear focus.
  """
  def handle_key_escape(%State{} = state) do
    State.set_focused(state, nil)
  end

  @doc """
  Handle scroll wheel input.
  """
  def handle_scroll(%State{} = state, {_dx, dy}) do
    # Scroll down = positive dy, move content up (increase offset)
    # Scenic's scroll events use this convention
    scroll_speed = 40  # pixels per scroll tick
    new_offset = state.scroll_offset + (dy * scroll_speed)
    State.set_scroll_offset(state, new_offset)
  end

  # Private helpers

  defp auto_scroll_to_item(%State{} = state, item_id) do
    case Map.get(state.item_bounds, item_id) do
      nil ->
        state

      bounds ->
        viewport_height = state.frame.size.height
        item_top = bounds.y
        item_bottom = bounds.y + bounds.height

        # Calculate visible range
        visible_top = state.scroll_offset
        visible_bottom = state.scroll_offset + viewport_height

        new_offset = cond do
          # Item is above visible area - scroll up to show it at top
          item_top < visible_top ->
            item_top

          # Item is below visible area - scroll down to show it at bottom
          item_bottom > visible_bottom ->
            item_bottom - viewport_height

          # Item is already visible
          true ->
            state.scroll_offset
        end

        State.set_scroll_offset(state, new_offset)
    end
  end

  defp find_parent(tree, target_id) do
    do_find_parent(tree, target_id, nil)
  end

  defp do_find_parent([], _target_id, _parent_id), do: nil

  defp do_find_parent([item | rest], target_id, parent_id) do
    item_id = Item.get_id(item)

    if Item.has_children?(item) do
      # Check if target is a direct child
      child_ids = Enum.map(Item.get_children(item), &Item.get_id/1)

      if Enum.member?(child_ids, target_id) do
        item_id
      else
        # Search in children recursively
        case do_find_parent(Item.get_children(item), target_id, item_id) do
          nil -> do_find_parent(rest, target_id, parent_id)
          found -> found
        end
      end
    else
      do_find_parent(rest, target_id, parent_id)
    end
  end
end
