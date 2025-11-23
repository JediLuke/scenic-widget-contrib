defmodule ScenicWidgets.SideNav.Renderizer do
  @moduledoc """
  Rendering logic for the SideNav component.

  Follows HexDocs visual style:
  - Hierarchical tree with indentation
  - Chevron icons for expandable nodes (right = collapsed, down = expanded)
  - Text labels with overflow handling
  - Active item highlighting with left accent bar
  - Hover states
  - Focus ring for keyboard navigation
  - Scrollable viewport with scissor clipping
  """

  alias Scenic.Graph
  alias Scenic.Primitives
  alias ScenicWidgets.SideNav.{State, Item}

  @doc """
  Perform initial render of the entire sidebar.
  This builds the complete graph structure.
  """
  def initial_render(graph, %State{} = state) do
    graph
    |> Primitives.group(
      fn g ->
        g
        # Background
        |> Primitives.rect(
          state.frame.size.box,
          id: :sidebar_background,
          fill: state.theme.background
        )
        # Scrollable content area (with scissor clipping)
        |> Primitives.group(
          fn scroll_g ->
            scroll_g
            |> render_tree(state.tree, state, 0)
          end,
          id: :sidebar_scroll_group,
          translate: {0, -state.scroll_offset},
          scissor: state.frame.size.box
        )
      end,
      translate: state.frame.pin.point
    )
  end

  @doc """
  Update render - only modifies changed elements.
  More efficient than full re-render for state changes like hover, scroll, expand/collapse.
  """
  def update_render(graph, old_state, new_state) do
    cond do
      # Tree structure changed (expand/collapse) - need full re-render of content
      old_state.expanded != new_state.expanded ->
        graph
        |> Graph.modify(:sidebar_scroll_group, fn primitive ->
          # Clear and rebuild the scroll group
          Graph.build()
          |> render_tree(new_state.tree, new_state, 0)
          |> Graph.get_root()
        end)
        |> update_scroll_transform(new_state)

      # Scroll offset changed - just update transform
      old_state.scroll_offset != new_state.scroll_offset ->
        update_scroll_transform(graph, new_state)

      # Hover/focus/active changed - update individual item styling
      old_state.hovered_id != new_state.hovered_id ||
      old_state.focused_id != new_state.focused_id ||
      old_state.active_id != new_state.active_id ->
        update_item_states(graph, old_state, new_state)

      # No visual changes
      true ->
        graph
    end
  end

  # Recursively render tree structure
  defp render_tree(graph, items, state, depth) when is_list(items) do
    Enum.reduce(items, graph, fn item, acc_graph ->
      item_id = Item.get_id(item)
      is_expanded = MapSet.member?(state.expanded, item_id)

      # Render this item
      new_graph = render_item(acc_graph, item, state, depth, is_expanded)

      # If expanded and has children, render children
      if is_expanded && Item.has_children?(item) do
        render_tree(new_graph, Item.get_children(item), state, depth + 1)
      else
        new_graph
      end
    end)
  end

  # Render a single item
  defp render_item(graph, item, state, depth, is_expanded) do
    item_id = Item.get_id(item)
    bounds = Map.get(state.item_bounds, item_id)

    if bounds do
      theme = state.theme
      is_active = state.active_id == item_id
      is_focused = state.focused_id == item_id
      is_hovered = Map.get(state, :hovered_id) == item_id
      has_children = Item.has_children?(item)

      # Calculate positions
      x = bounds.x + theme.padding_left
      y = bounds.y
      text_x = x + if has_children do
        theme.chevron_size + theme.chevron_margin
      else
        0
      end

      # Determine colors based on state
      {bg_fill, text_fill} = cond do
        is_active ->
          {theme.active_bg, theme.text}

        is_hovered ->
          {theme.hover_bg, theme.text}

        true ->
          {theme.background, theme.text}
      end

      graph
      # Item background (full width)
      |> Primitives.rect(
        {state.frame.size.width, theme.item_height},
        id: {:item_bg, item_id},
        fill: bg_fill,
        translate: {0, y}
      )
      # Active accent bar (left side, only if active)
      |> then(fn g ->
        if is_active do
          g
          |> Primitives.rect(
            {3, theme.item_height},
            fill: theme.active_bar,
            translate: {0, y}
          )
        else
          g
        end
      end)
      # Chevron icon (if has children)
      |> then(fn g ->
        if has_children do
          render_chevron(g, {x, y + (theme.item_height - theme.chevron_size) / 2}, is_expanded, theme)
        else
          g
        end
      end)
      # Text label
      |> Primitives.text(
        Item.get_title(item),
        id: {:item_text, item_id},
        fill: text_fill,
        font: theme.font,
        font_size: theme.font_size,
        translate: {text_x, y + theme.item_height / 2 + calculate_v_pos(theme)},
        t: {text_x, y + theme.item_height / 2}
      )
      # Focus ring (if focused)
      |> then(fn g ->
        if is_focused do
          g
          |> Primitives.rect(
            {state.frame.size.width - 2, theme.item_height - 2},
            stroke: {2, theme.focus_ring},
            fill: :clear,
            translate: {1, y + 1}
          )
        else
          g
        end
      end)
    else
      # Item not visible (hidden by collapsed parent)
      graph
    end
  end

  # Render chevron icon
  defp render_chevron(graph, {x, y}, is_expanded, theme) do
    # For now, use a simple text arrow
    # TODO: Use proper SVG/image icons like MenuBar does
    arrow = if is_expanded, do: "▼", else: "▶"

    graph
    |> Primitives.text(
      arrow,
      fill: theme.chevron,
      font: theme.font,
      font_size: theme.chevron_size,
      translate: {x, y + theme.chevron_size}
    )
  end

  # Update scroll transform only
  defp update_scroll_transform(graph, state) do
    graph
    |> Graph.modify(:sidebar_scroll_group, fn primitive ->
      Scenic.Primitive.put_style(primitive, :translate, {0, -state.scroll_offset})
    end)
  end

  # Update item visual states (hover/focus/active)
  defp update_item_states(graph, old_state, new_state) do
    # Collect all items that changed state
    changed_items = collect_changed_items(old_state, new_state)

    # Update each changed item's background and text color
    Enum.reduce(changed_items, graph, fn item_id, acc_graph ->
      update_item_styling(acc_graph, item_id, new_state)
    end)
  end

  defp collect_changed_items(old_state, new_state) do
    [
      old_state.hovered_id,
      new_state.hovered_id,
      old_state.focused_id,
      new_state.focused_id,
      old_state.active_id,
      new_state.active_id
    ]
    |> Enum.filter(& &1 != nil)
    |> Enum.uniq()
  end

  defp update_item_styling(graph, item_id, state) do
    is_active = state.active_id == item_id
    is_focused = state.focused_id == item_id
    is_hovered = Map.get(state, :hovered_id) == item_id

    theme = state.theme

    {bg_fill, text_fill} = cond do
      is_active ->
        {theme.active_bg, theme.text}

      is_hovered ->
        {theme.hover_bg, theme.text}

      true ->
        {theme.background, theme.text}
    end

    # Try to update background
    graph = try do
      graph
      |> Graph.modify({:item_bg, item_id}, fn primitive ->
        Scenic.Primitive.put_style(primitive, :fill, bg_fill)
      end)
    rescue
      _ -> graph
    end

    # Try to update text color
    graph = try do
      graph
      |> Graph.modify({:item_text, item_id}, fn primitive ->
        Scenic.Primitive.put_style(primitive, :fill, text_fill)
      end)
    rescue
      _ -> graph
    end

    graph
  end

  # Calculate vertical position for text (centering)
  defp calculate_v_pos(theme) do
    # Use Scenic's font metrics if available
    # For now, use a simple approximation
    font_size = theme.font_size
    -font_size / 3
  end
end
