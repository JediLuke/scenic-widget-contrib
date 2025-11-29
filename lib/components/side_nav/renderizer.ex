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
    {width, height} = state.frame.size.box
    border_color = Map.get(state.theme, :border, {220, 220, 220})

    # Note: Parent component positions us via `translate:` option in add_to_graph
    # So we render at local origin (0,0) - do NOT apply frame.pin.point here
    # as that would cause double-positioning
    graph
    |> Primitives.group(
      fn g ->
        g
        # Background with border
        |> Primitives.rect(
          state.frame.size.box,
          id: :sidebar_background,
          fill: state.theme.background,
          stroke: {1, border_color}
        )
        # Scrollable content area (with scissor clipping)
        |> Primitives.group(
          fn scroll_g ->
            scroll_g
            |> render_tree(state.tree, state, 0)
          end,
          id: :sidebar_scroll_group,
          translate: {0, -state.scroll_offset},
          scissor: {width - 2, height - 2}  # Account for border
        )
      end,
      # Render at local origin - parent handles positioning via translate
      translate: {0, 0}
    )
  end

  @doc """
  Update render - only modifies changed elements.
  More efficient than full re-render for state changes like hover, scroll, expand/collapse.
  """
  def update_render(graph, old_state, new_state) do
    cond do
      # Tree structure changed (expand/collapse) - need full re-render
      old_state.expanded != new_state.expanded ->
        initial_render(Graph.build(), new_state)

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

  # Render a single item as a self-contained row group
  # Each row is a group translated to its y position, containing:
  # - Background rect (full width, at y=0 within group)
  # - Optional active accent bar
  # - Optional chevron (vertically centered)
  # - Text label (vertically centered)
  # - Optional focus ring
  defp render_item(graph, item, state, depth, is_expanded) do
    item_id = Item.get_id(item)
    bounds = Map.get(state.item_bounds, item_id)

    if bounds do
      theme = state.theme
      is_active = state.active_id == item_id
      is_focused = state.focused_id == item_id
      is_hovered = Map.get(state, :hovered_id) == item_id
      has_children = Item.has_children?(item)

      # Row positioning
      row_y = bounds.y
      row_height = theme.item_height
      row_width = state.frame.size.width

      # X positions within the row (relative to row start)
      indent_x = theme.padding_left + (depth * theme.indent)
      chevron_area_width = theme.chevron_size + theme.chevron_margin
      text_x = indent_x + chevron_area_width

      # Vertical center of the row (for centering elements)
      v_center = row_height / 2

      # Determine colors based on state
      {bg_fill, text_fill} = cond do
        is_active -> {theme.active_bg, theme.text}
        is_hovered -> {theme.hover_bg, theme.text}
        true -> {theme.background, theme.text}
      end

      # Build semantic IDs
      row_id = String.to_atom("row_#{item_id}")
      text_id = String.to_atom("item_text_#{item_id}")

      # Render the entire row as a group
      graph
      |> Primitives.group(
        fn g ->
          g
          # Background (full width, starts at 0,0 within group)
          |> Primitives.rect({row_width, row_height}, fill: bg_fill)
          # Active accent bar (left edge)
          |> then(fn g2 ->
            if is_active do
              Primitives.rect(g2, {3, row_height}, fill: theme.active_bar)
            else
              g2
            end
          end)
          # Chevron (if has children) - centered vertically
          |> then(fn g2 ->
            if has_children do
              # Chevron centered vertically in the row
              chevron_y = v_center - theme.chevron_size / 2
              render_chevron_local(g2, indent_x, chevron_y, theme.chevron_size, is_expanded, theme.chevron, item_id)
            else
              g2
            end
          end)
          # Text label - centered vertically
          |> Primitives.text(
            Item.get_title(item),
            id: text_id,
            fill: text_fill,
            font: theme.font,
            font_size: theme.font_size,
            translate: {text_x, v_center + theme.font_size / 3}
          )
          # Focus ring
          |> then(fn g2 ->
            if is_focused do
              Primitives.rect(g2, {row_width - 2, row_height - 2},
                stroke: {2, theme.focus_ring},
                fill: :clear,
                translate: {1, 1}
              )
            else
              g2
            end
          end)
        end,
        id: row_id,
        translate: {0, row_y}
      )
    else
      graph
    end
  end

  # Render chevron with local coordinates (within row group)
  defp render_chevron_local(graph, x, y, size, is_expanded, color, item_id) do
    chevron_id = String.to_atom("chevron_#{item_id}")

    # Center of chevron
    cx = x + size / 2
    cy = y + size / 2

    # Triangle points
    points = if is_expanded do
      # Pointing down
      [
        {cx - size * 0.35, cy - size * 0.15},
        {cx + size * 0.35, cy - size * 0.15},
        {cx, cy + size * 0.3}
      ]
    else
      # Pointing right
      [
        {cx - size * 0.15, cy - size * 0.35},
        {cx - size * 0.15, cy + size * 0.35},
        {cx + size * 0.3, cy}
      ]
    end

    graph
    |> Primitives.triangle(List.to_tuple(points), id: chevron_id, fill: color)
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

    # Build semantic IDs (must match those in render_item)
    bg_id = String.to_atom("item_bg_#{item_id}")
    text_id = String.to_atom("item_text_#{item_id}")

    # Try to update background
    graph = try do
      graph
      |> Graph.modify(bg_id, fn primitive ->
        Scenic.Primitive.put_style(primitive, :fill, bg_fill)
      end)
    rescue
      _ -> graph
    end

    # Try to update text color
    graph = try do
      graph
      |> Graph.modify(text_id, fn primitive ->
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
