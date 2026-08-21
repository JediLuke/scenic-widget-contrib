defmodule ScenicWidgets.Menu.Dropdown do
  @moduledoc """
  A panel of menu rows, drawn wherever you hang it.

  This was the second half of `ScenicWidgets.IconMenu.Renderer`, reachable
  only by that component — so anything else wanting a menu-shaped popover had
  to write its own, which is exactly what the search pane did. What made it
  un-reusable was never the drawing; it was that every function took the
  BAR's state and read `active_menu` out of it. A panel does not need to know
  it belongs to a bar.

  It takes rows (`ScenicWidgets.Menu.Model` structs, or the old
  `{id, label}` tuples), a `bounds` map saying where the panel goes and where
  each row sits inside it, and a theme. It returns a graph.

      Dropdown.render(graph, rows, bounds,
        theme: theme,
        hovered: hovered_item_id,
        show_shortcuts: true,
        id: :my_panel
      )

  `bounds` is `%{x:, y:, width:, height:, items: %{id => %{y:, height:}}}`,
  which is what `IconMenu.State.calculate_dropdown_bounds/1` already built —
  laid out by the caller, because where a panel can go depends on what it
  hangs off and how much room is under it, and that IS the caller's business.
  """

  alias Scenic.Primitives
  alias ScenicWidgets.Menu.Model
  alias ScenicWidgets.MenuBar.TextHelper

  @doc """
  Where the panel goes, and where each row sits inside it.

  The caller supplies the ANCHOR — `x`, `y` and `width` — because where a
  panel can appear depends on what it hangs off, and that is the one part of
  this that genuinely differs between a menubar and anything else. Everything
  below the anchor is the same arithmetic wherever the panel is, so it is
  here rather than copied.

  `:max_height` clamps a panel taller than the room under it; `:scroll` is
  then how far down it has been wound, clamped to the overflow. Both drawing
  and hit testing read the SAME map, which is what stops them disagreeing
  about where a row is.
  """
  def layout(rows, theme, opts) do
    x = Keyword.fetch!(opts, :x)
    y = Keyword.fetch!(opts, :y)
    width = Keyword.fetch!(opts, :width)
    padding = theme.dropdown_padding

    content_height =
      Enum.sum(Enum.map(rows, &Model.item_height(&1, theme))) + 2 * padding

    height =
      case Keyword.get(opts, :max_height) do
        max when is_number(max) and max > 0 -> min(content_height, max)
        _ -> content_height
      end

    scroll = min(Keyword.get(opts, :scroll, 0), max(content_height - height, 0))

    items =
      rows
      |> Enum.map_reduce(0, fn row, offset ->
        row_height = Model.item_height(row, theme)

        {{Model.get_item_id(row),
          %{
            x: x + padding,
            y: y + padding + offset - scroll,
            width: width - 2 * padding,
            height: row_height
          }}, offset + row_height}
      end)
      |> elem(0)
      |> Enum.into(%{})

    %{
      x: x,
      y: y,
      width: width,
      height: height,
      content_height: content_height,
      scroll: scroll,
      items: items
    }
  end

  @doc """
  Which row is under a point, and where inside that row it landed.

  Returns `{row_id, {local_x, local_y}}` — local to the ROW, which is what
  every row type's behaviour is written in terms of — or `:panel` for a click
  that hit the panel but no row, or `nil` for one that missed entirely.
  """
  def row_at(bounds, {x, y}) do
    inside? =
      x >= bounds.x and x <= bounds.x + bounds.width and
        y >= bounds.y and y <= bounds.y + bounds.height

    cond do
      not inside? ->
        nil

      true ->
        Enum.find_value(bounds.items, :panel, fn {id, b} ->
          if y >= b.y and y < b.y + b.height, do: {id, {x - b.x, y - b.y}}
        end)
    end
  end

  @doc """
  Draw a panel of rows.

  The panel is translated to `bounds.x/y`, so rows inside it are positioned
  relative to the panel and never have to know where on the screen it landed.
  """
  def render(graph, rows, bounds, opts) do
    theme = Keyword.fetch!(opts, :theme)
    hovered = Keyword.get(opts, :hovered)
    show_shortcuts = Keyword.get(opts, :show_shortcuts, true)
    id = Keyword.get(opts, :id, :dropdown_group)

    Primitives.group(
      graph,
      fn g ->
        g
        |> Primitives.rrect({bounds.width, bounds.height, 4},
          id: :dropdown_bg,
          fill: theme.dropdown_bg,
          stroke: {1, theme.dropdown_border}
        )
        |> Primitives.group(
          fn inner -> render_rows(inner, rows, bounds, theme, hovered, show_shortcuts) end,
          id: :dropdown_items_group,
          # A clamped panel scrolls, so its rows have to be clipped to it.
          # Without this the overflow is simply drawn past the bottom edge —
          # over the document, and over nothing at all below the window.
          scissor: {bounds.width, bounds.height}
        )
      end,
      id: id,
      translate: {bounds.x, bounds.y}
    )
  end

  defp render_rows(graph, items, dropdown, theme, hovered_item, show_shortcuts) do
    padding = theme.dropdown_padding

    # Space reserved for checkmark on the left
    checkmark_width = 20

    Enum.reduce(items, graph, fn item, acc ->
      item_id = Model.get_item_id(item)
      label = Model.display_label(item)
      shortcut = Model.item_shortcut(item, show_shortcuts)
      is_toggle = Model.is_toggle_item?(item)
      is_checked = Model.is_item_checked?(item)
      item_bounds = Map.fetch!(dropdown.items, item_id)

      is_hovered = hovered_item == item_id

      # Position relative to dropdown origin
      item_x = padding
      item_y = item_bounds.y - dropdown.y
      row_height = item_bounds.height

      bg_color = if is_hovered, do: theme.item_hover_bg, else: :clear
      enabled? = Model.item_enabled?(item)

      text_color =
        cond do
          not enabled? -> {120, 120, 120}
          is_hovered -> theme.item_hover_text_color
          true -> theme.item_text_color
        end

      if match?(%Model.Divider{}, item) do
        divider_y = row_height / 2

        acc
        |> Primitives.line(
          {{8, divider_y}, {dropdown.width - 2 * padding - 8, divider_y}},
          id: {:menu_divider, item_id},
          stroke: {1, Map.get(theme, :dropdown_border, {70, 70, 70})},
          translate: {item_x, item_y}
        )
      else
        acc
        |> Primitives.group(
          fn g ->
            g =
              g
              # Item background (for hover)
              |> Primitives.rrect(
                {dropdown.width - 2 * padding, row_height, 3},
                id: {:item_bg, item_id},
                fill: bg_color
              )

            # Checkmark for toggle items (only if checked)
            g =
              if is_toggle and is_checked do
                g
                |> Primitives.text(
                  "✓",
                  id: {:item_check, item_id},
                  fill: text_color,
                  font: theme.font,
                  font_size: theme.dropdown_font_size,
                  translate: {6, theme.dropdown_item_height / 2 + theme.dropdown_font_size / 3}
                )
              else
                g
              end

            cond do
              match?(%Model.Tree{}, item) ->
                render_tree(g, item, dropdown.width - 2 * padding, text_color, theme)

              match?(%Model.Select{}, item) ->
                render_select(g, item, dropdown.width - 2 * padding, text_color, theme)

              match?(%Model.Stepper{}, item) ->
                render_stepper(g, item, dropdown.width - 2 * padding, text_color, theme)

              match?(%Model.Slider{}, item) ->
                render_slider(
                  g,
                  item,
                  dropdown.width - 2 * padding,
                  text_color,
                  is_hovered,
                  theme
                )

              true ->
                text_x = if has_any_toggle_items?(items), do: checkmark_width, else: 8
                shortcut_right = dropdown.width - 2 * padding - 8
                column_gap = Map.get(theme, :dropdown_column_gap, 24)
                available_width = shortcut_right - text_x
                measured_shortcut_width = measure_width(shortcut || "", theme)

                shortcut_width =
                  if shortcut do
                    min(measured_shortcut_width, max(40, available_width * 0.55))
                  else
                    0
                  end

                label_max_width =
                  max(
                    0,
                    shortcut_right - text_x -
                      if(shortcut, do: shortcut_width + column_gap, else: 0)
                  )

                display_label = truncate(label, label_max_width, theme)
                display_shortcut = shortcut && truncate(shortcut, shortcut_width, theme)

                g =
                  Primitives.text(g, display_label,
                    id: {:item_text, item_id},
                    fill: text_color,
                    font: theme.font,
                    font_size: theme.dropdown_font_size,
                    translate:
                      {text_x, theme.dropdown_item_height / 2 + theme.dropdown_font_size / 3}
                  )

                if display_shortcut do
                  Primitives.text(g, display_shortcut,
                    id: {:item_shortcut, item_id},
                    fill: text_color,
                    font: theme.font,
                    font_size: theme.dropdown_font_size,
                    text_align: :right,
                    translate: {
                      shortcut_right,
                      theme.dropdown_item_height / 2 + theme.dropdown_font_size / 3
                    }
                  )
                else
                  g
                end
            end
          end,
          id: {:dropdown_item, item_id},
          translate: {item_x, item_y}
        )
      end
    end)
  end

  defp render_stepper(graph, stepper, row_width, text_color, theme) do
    baseline = theme.dropdown_item_height / 2 + theme.dropdown_font_size / 3
    center_y = theme.dropdown_item_height / 2
    controls_width = 116
    controls_x = row_width - controls_width - 8
    button_fill = Map.get(theme, :stepper_button_bg, {72, 78, 92})

    graph
    |> Primitives.text(stepper.label,
      id: {:stepper_label, stepper.id},
      fill: text_color,
      font: theme.font,
      font_size: theme.dropdown_font_size,
      translate: {8, baseline}
    )
    |> Primitives.rrect({28, 22, 4},
      id: {:stepper_minus_bg, stepper.id},
      fill: button_fill,
      stroke: {1, theme.dropdown_border},
      translate: {controls_x, center_y - 11}
    )
    |> Primitives.text("−",
      id: {:stepper_minus, stepper.id},
      fill: text_color,
      font: theme.font,
      font_size: theme.dropdown_font_size,
      text_align: :center,
      text_base: :middle,
      translate: {controls_x + 14, center_y}
    )
    |> Primitives.text("#{stepper.value}%",
      id: {:stepper_value, stepper.id},
      fill: text_color,
      font: theme.font,
      font_size: theme.dropdown_font_size,
      text_align: :center,
      text_base: :middle,
      translate: {controls_x + 58, center_y}
    )
    |> Primitives.rrect({28, 22, 4},
      id: {:stepper_plus_bg, stepper.id},
      fill: button_fill,
      stroke: {1, theme.dropdown_border},
      translate: {controls_x + 88, center_y - 11}
    )
    |> Primitives.text("+",
      id: {:stepper_plus, stepper.id},
      fill: text_color,
      font: theme.font,
      font_size: theme.dropdown_font_size,
      text_align: :center,
      text_base: :middle,
      translate: {controls_x + 102, center_y}
    )
  end

  # A tree of tickable things, opening in place — the same arrangement as an
  # expanded Select, one level per indent. Its triangle and its tick are DRAWN
  # rather than typed: a font that has no ▸ draws an empty box instead, and a
  # box beside every folder is worse than no triangle at all.
  defp render_tree(graph, tree, row_width, text_color, theme) do
    row_height = theme.dropdown_item_height
    baseline = row_height / 2 + theme.dropdown_font_size / 3

    graph
    |> Primitives.text(ScenicWidgets.IconMenu.Model.display_label(tree),
      id: {:tree_label, tree.id},
      fill: text_color,
      font: theme.font,
      font_size: theme.dropdown_font_size,
      translate: {8, baseline}
    )
    |> caret(row_width - 16, row_height / 2, tree.expanded?, text_color)
    |> render_tree_nodes(tree, row_width, row_height, text_color, theme)
  end

  defp render_tree_nodes(graph, %{expanded?: false}, _w, _h, _colour, _theme), do: graph

  defp render_tree_nodes(graph, tree, row_width, row_height, text_color, theme) do
    tree
    |> Model.visible_tree_nodes()
    |> Enum.drop(tree.scroll_offset)
    |> Enum.take(tree.max_visible)
    |> Enum.with_index()
    |> Enum.reduce(graph, fn {{node, depth}, i}, g ->
      y = (i + 1) * row_height
      x = 8 + depth * Model.tree_indent()

      g
      |> then(fn gg ->
        if node.children == [],
          do: gg,
          else: caret(gg, x + 4, y + row_height / 2, node.expanded?, text_color)
      end)
      |> tick_box(x + Model.tree_indent(), y + row_height / 2, node.checked?, text_color, theme)
      |> Primitives.text(node.label,
        id: {:tree_node, tree.id, node.id},
        fill: text_color,
        font: theme.font,
        font_size: theme.dropdown_font_size,
        translate: {x + Model.tree_indent() + 16, y + row_height / 2 + theme.dropdown_font_size / 3}
      )
    end)
    |> then(fn g ->
      # Say so when there is more of it than fits, rather than simply ending.
      total = Model.tree_node_count(tree)
      shown = min(total - tree.scroll_offset, tree.max_visible)

      if total > tree.max_visible do
        Primitives.text(g, "#{total - shown - tree.scroll_offset} more…",
          fill: text_color,
          font: theme.font,
          font_size: theme.dropdown_font_size - 1,
          translate: {row_width - 70, (tree.max_visible + 1) * row_height - 6}
        )
      else
        g
      end
    end)
  end

  # A disclosure triangle, drawn: right when shut, down when open.
  defp caret(graph, x, y, open?, colour) do
    points =
      if open?,
        do: [{x - 4, y - 2}, {x + 4, y - 2}, {x, y + 3}],
        else: [{x - 2, y - 4}, {x + 3, y}, {x - 2, y + 4}]

    Primitives.triangle(graph, List.to_tuple(points), fill: colour)
  end

  # A tick box, drawn for the same reason.
  defp tick_box(graph, x, y, checked?, colour, _theme) do
    graph
    |> Primitives.rrect({11, 11, 2},
      fill: :clear,
      stroke: {1, colour},
      translate: {x, y - 5.5}
    )
    |> then(fn g ->
      if checked? do
        g
        |> Primitives.line({{x + 2.5, y}, {x + 4.5, y + 3}}, stroke: {1.6, colour}, cap: :round)
        |> Primitives.line({{x + 4.5, y + 3}, {x + 8.5, y - 3.5}}, stroke: {1.6, colour}, cap: :round)
      else
        g
      end
    end)
  end

  defp render_select(graph, select, row_width, text_color, theme) do
    row_height = theme.dropdown_item_height
    box_width = 76
    box_x = row_width - box_width - 8
    baseline = row_height / 2 + theme.dropdown_font_size / 3

    graph
    |> Primitives.text(select.label,
      id: {:select_label, select.id},
      fill: text_color,
      font: theme.font,
      font_size: theme.dropdown_font_size,
      translate: {8, baseline}
    )
    |> Primitives.rrect({box_width, row_height - 8, 3},
      id: {:select_box, select.id},
      fill: :clear,
      stroke: {1, theme.dropdown_border},
      translate: {box_x, 4}
    )
    |> Primitives.text(to_string(select.value),
      id: {:select_value, select.id},
      fill: text_color,
      font: theme.font,
      font_size: theme.dropdown_font_size,
      text_align: :center,
      translate: {box_x + box_width / 2 - 7, baseline}
    )
    |> Primitives.text("▾",
      id: {:select_arrow, select.id},
      fill: text_color,
      font: theme.font,
      font_size: theme.dropdown_font_size,
      text_align: :center,
      translate: {box_x + box_width - 13, baseline}
    )
    |> render_select_options(select, row_width, row_height, text_color, theme)
  end

  defp render_select_options(graph, %{expanded?: false}, _width, _height, _color, _theme),
    do: graph

  defp render_select_options(graph, select, row_width, row_height, text_color, theme) do
    select.options
    |> Enum.drop(select.scroll_offset)
    |> Enum.take(4)
    |> Enum.with_index()
    |> Enum.reduce(graph, fn {value, index}, acc ->
      y = row_height * (index + 1)

      acc
      |> Primitives.rect({76, row_height},
        id: {:select_option_bg, select.id, value},
        fill: if(value == select.value, do: theme.item_hover_bg, else: theme.dropdown_bg),
        translate: {row_width - 84, y}
      )
      |> Primitives.text(to_string(value),
        id: {:select_option, select.id, value},
        fill: text_color,
        font: theme.font,
        font_size: theme.dropdown_font_size,
        text_align: :center,
        translate: {row_width - 46, y + row_height / 2 + theme.dropdown_font_size / 3}
      )
    end)
  end

  defp render_slider(graph, slider, row_width, text_color, hovered?, theme) do
    track_x = 10
    track_width = max(1, row_width - 20)
    track_y = Map.get(theme, :dropdown_slider_height, 52) - 13
    ratio = (slider.value - slider.min) / max(slider.max - slider.min, 1)
    thumb_x = track_x + ratio * track_width
    font_y = theme.dropdown_font_size + 5

    {track_color, fill_color, thumb_color} =
      if hovered? do
        {
          Map.get(theme, :item_hover_text_color, {255, 255, 255}),
          Map.get(theme, :dropdown_bg, {50, 50, 50}),
          Map.get(theme, :dropdown_bg, {50, 50, 50})
        }
      else
        {
          Map.get(theme, :dropdown_border, {70, 70, 70}),
          Map.get(theme, :item_hover_bg, {0, 122, 204}),
          text_color
        }
      end

    graph
    |> Primitives.text(slider.label,
      id: {:slider_label, slider.id},
      fill: text_color,
      font: theme.font,
      font_size: theme.dropdown_font_size,
      translate: {8, font_y}
    )
    |> Primitives.text(to_string(slider.value),
      id: {:slider_value, slider.id},
      fill: text_color,
      font: theme.font,
      font_size: theme.dropdown_font_size,
      text_align: :right,
      translate: {row_width - 8, font_y}
    )
    |> Primitives.rrect({track_width, 4, 2},
      id: {:slider_track, slider.id},
      fill: track_color,
      translate: {track_x, track_y}
    )
    |> Primitives.rrect({max(0, thumb_x - track_x), 4, 2},
      id: {:slider_fill, slider.id},
      fill: fill_color,
      translate: {track_x, track_y}
    )
    |> Primitives.circle(6,
      id: {:slider_thumb, slider.id},
      fill: thumb_color,
      translate: {thumb_x, track_y + 2}
    )
  end

  # Check if any item in the list is a toggle type (to align text consistently)
  defp has_any_toggle_items?(items) do
    Enum.any?(items, &Model.is_toggle_item?/1)
  end

  defp measure_width("", _theme), do: 0

  defp measure_width(text, theme) do
    case TextHelper.measure_text(text, font: theme.font, font_size: theme.dropdown_font_size) do
      {:ok, width} -> width
      {:error, _} -> String.length(text) * theme.dropdown_font_size * 0.6
    end
  end

  defp truncate(text, width, theme) do
    case TextHelper.truncate_text(text, width,
           font: theme.font,
           font_size: theme.dropdown_font_size,
           ellipsis: "…"
         ) do
      {:ok, value} -> value
      {:truncated, value} -> value
      {:error, _} -> text
    end
  end

  # ===========================================================================
  # Update Rendering
  # ===========================================================================
end
