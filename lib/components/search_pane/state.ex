defmodule ScenicWidgets.SearchPane.State do
  @moduledoc """
  Layout and interaction state for `ScenicWidgets.SearchPane`.

  The pane is two regions stacked in one frame:

    * a **header** that does not scroll — the query and replacement
      fields, the `Aa`/`.*` option toggles, Replace All, and a status line;
    * a **body** that does — the SCOPE tree and the results, grouped by file.

  Everything drawable is described here as a rectangle so that one list serves
  drawing, hit testing and semantic registration. `header_widgets/1` returns the
  header's rectangles in frame-local coordinates; `rows/1` returns the body's in
  *content* coordinates (i.e. before the scroll offset is applied), the same
  convention `SideNav` uses for `item_bounds`.

  The three text fields are owned here rather than by the parent. A field whose
  contents arrived from outside on every keystroke would fight the person
  typing into it; the parent is told what changed and does not tell the pane
  what it now holds.
  """

  alias Widgex.Scroll.ScrollState

  @default_theme %{
    background: {30, 30, 34},
    header_background: {38, 38, 44},
    border: {70, 70, 82},
    text: {220, 220, 228},
    dim_text: {150, 150, 162},
    heading: {160, 170, 200},
    field_background: {22, 22, 26},
    field_border: {80, 80, 96},
    field_focus_border: {90, 140, 220},
    match_highlight: {96, 78, 30},
    match_text: {255, 214, 120},
    row_hover: {48, 48, 58},
    button_background: {52, 52, 64},
    button_active: {70, 110, 180},
    button_text: {215, 220, 232},
    error_text: {240, 130, 130},
    scrollbar_color: {120, 120, 132},
    font: :roboto_mono,
    font_size: 13,
    small_font_size: 11,
    row_height: 20,
    field_height: 24,
    padding: 8,
    indent: 14
  }

  @fields [:query, :replace]

  defstruct [
    :frame,
    :theme,
    :model,
    :scroll,
    query: "",
    replace: "",
    focused_field: :query,
    focused: false,
    hovered: nil,
    collapsed_files: MapSet.new(),
    expanded_scope: MapSet.new(),
    scope_open?: false,
    # The search-domain disclosure: which files this search is allowed to
    # look at. Shut by default — the default domain is right nearly always,
    # and the pane is mostly for reading results.
    domain_open?: false,
    # :tree groups matches under their file, :list gives one row per match.
    results_view: :tree,
    scrollbar_drag: nil,
    scrollbar_drag_start: nil,
    scrollbar_drag_offset: nil
  ]

  @doc "The theme every SearchPane starts from; parents override keys piecemeal."
  def default_theme, do: @default_theme

  @doc "The names of the three editable fields, in Tab order."
  def fields, do: @fields

  def new(data) do
    theme = Map.merge(@default_theme, Map.get(data, :theme, %{}))
    model = normalize_model(Map.get(data, :model, %{}))
    query = Map.get(data, :query, "")

    state = %__MODULE__{
      frame: data.frame,
      theme: theme,
      model: model,
      query: query,
      replace: Map.get(data, :replace, ""),
      focused: Map.get(data, :focused, false),
      focused_field: Map.get(data, :focus_field, :query),
      scroll: ScrollState.new(data.frame, content_height: 0, direction: :vertical)
    }

    resync_scroll(state)
  end

  @doc """
  A model with every key the pane draws from, defaulted.

  The parent publishes results asynchronously, so the pane must be drawable
  before the first snapshot lands.
  """
  def normalize_model(model) do
    %{
      status: Map.get(model, :status, :idle),
      error: Map.get(model, :error),
      case_sensitive: Map.get(model, :case_sensitive, false),
      regex: Map.get(model, :regex, false),
      # Where the search is allowed to look. Hidden behind a disclosure,
      # because most searches want the default and a row of switches above
      # the results is a row of results you cannot see.
      open_buffers_only: Map.get(model, :open_buffers_only, false),
      use_ignore_files: Map.get(model, :use_ignore_files, true),
      scope: Map.get(model, :scope, []),
      files: Map.get(model, :files, [])
    }
  end

  def put_model(%__MODULE__{} = state, model) do
    resync_scroll(%{state | model: normalize_model(model)})
  end

  def put_frame(%__MODULE__{} = state, frame) do
    scroll = ScrollState.update_viewport_size(state.scroll, body_frame(frame, state.theme))
    resync_scroll(%{state | frame: frame, scroll: scroll})
  end

  # ── Geometry ──────────────────────────────────────────────────────────────

  @doc "Height of the fixed header, in pixels."
  def header_height(%__MODULE__{theme: theme} = state),
    do: header_height(theme) + domain_rows(state) * theme.row_height

  def header_height(theme) do
    pad = theme.padding
    # title, query, replace, domain disclosure, status
    pad + theme.row_height + 2 * (theme.field_height + 4) + 6 + theme.row_height +
      theme.row_height + pad
  end

  @doc "The frame the scrolling body occupies, as its own Widgex.Frame."
  # The body starts under whatever the header currently is — which grows when
  # the domain section is open, so it cannot be measured from the theme alone.
  def body_frame(%__MODULE__{frame: frame} = state) do
    top = header_height(state)

    Widgex.Frame.new(%{
      pin: {0, top},
      size: {frame.size.width, max(frame.size.height - top, 0)}
    })
  end

  def body_frame(frame, theme) do
    Widgex.Frame.new(%{
      pin: {0, header_height(theme)},
      size: {frame.size.width, max(frame.size.height - header_height(theme), 0)}
    })
  end

  @doc """
  The header's clickable rectangles, in frame-local coordinates.

  Each is `%{id: term, x:, y:, w:, h:}`. Ids are what `handle_click` matches on
  and what the semantic layer publishes, so they double as the pane's API to
  anything driving it from outside.
  """
  def header_widgets(%__MODULE__{frame: frame, theme: theme} = state) do
    pad = theme.padding
    width = frame.size.width
    fh = theme.field_height
    toggle_w = 26
    all_w = 46

    title_y = pad
    query_y = title_y + theme.row_height
    replace_y = query_y + fh + 4
    domain_y = replace_y + fh + 6

    header =
      [
        %{id: :close, x: width - pad - 18, y: title_y, w: 18, h: theme.row_height},
        %{
          id: {:field, :query},
          x: pad,
          y: query_y,
          w: max(width - 2 * pad - 2 * toggle_w - 8, 40),
          h: fh
        },
        %{
          id: {:toggle, :case_sensitive},
          x: width - pad - 2 * toggle_w - 4,
          y: query_y,
          w: toggle_w,
          h: fh
        },
        %{id: {:toggle, :regex}, x: width - pad - toggle_w, y: query_y, w: toggle_w, h: fh},
        %{id: {:field, :replace}, x: pad, y: replace_y, w: max(width - 2 * pad - all_w - 6, 40), h: fh},
        %{id: :replace_all, x: width - pad - all_w, y: replace_y, w: all_w, h: fh},
        # The disclosure for the search domain. A named row rather than three
        # dots: a control that hides something should say what.
        %{id: :domain_header, x: pad, y: domain_y, w: width - 2 * pad, h: theme.row_height}
      ] ++ domain_widgets(state, domain_y + theme.row_height, width, pad, theme)

    header ++ [%{id: :status, x: pad, y: status_y(state), w: width - 2 * pad, h: theme.row_height}]
  end

  defp domain_widgets(%__MODULE__{domain_open?: false}, _y, _width, _pad, _theme), do: []

  defp domain_widgets(%__MODULE__{}, y, width, pad, theme) do
    row = theme.row_height

    [
      %{id: {:domain, :open_buffers_only}, x: pad, y: y, w: width - 2 * pad, h: row},
      %{id: {:domain, :use_ignore_files}, x: pad, y: y + row, w: width - 2 * pad, h: row}
    ]
  end

  @doc "How many rows the domain section adds when it is open."
  def domain_rows(%__MODULE__{domain_open?: true}), do: 2
  def domain_rows(%__MODULE__{}), do: 0

  defp status_y(%__MODULE__{theme: theme} = state) do
    pad = theme.padding
    fh = theme.field_height

    pad + theme.row_height + 2 * (fh + 4) + 6 + theme.row_height +
      domain_rows(state) * theme.row_height + 4
  end

  @doc """
  The body's rows, in content coordinates.

  Every row carries the actions drawn at its right edge, so the renderer, the
  hit test and the semantic registration cannot disagree about where a button
  is.
  """
  def rows(%__MODULE__{} = state) do
    %{theme: theme, model: model} = state
    h = theme.row_height

    scope_rows =
      case model.scope do
        [] ->
          []

        scope ->
          header = %{
            id: :scope_header,
            kind: :scope_header,
            label: scope_summary(scope),
            depth: 0,
            actions: []
          }

          if state.scope_open? do
            [header | scope_nodes(scope, state, 1)]
          else
            [header]
          end
      end

    file_rows =
      Enum.flat_map(model.files, fn file ->
        collapsed? = MapSet.member?(state.collapsed_files, file.path)

        head = %{
          id: {:file, file.path},
          kind: :file,
          label: "#{file.label}  (#{length(file.matches)})",
          path: file.path,
          depth: 0,
          collapsed?: collapsed?,
          actions: [{:replace_file, file.path}, {:dismiss_file, file.path}]
        }

        if collapsed? do
          [head]
        else
          [head | Enum.map(file.matches, &match_row(&1, file.path))]
        end
      end)

    (scope_rows ++ file_rows)
    |> Enum.with_index()
    |> Enum.map(fn {row, i} -> Map.merge(row, %{y: i * h, height: h}) end)
  end

  defp match_row(match, path) do
    %{
      id: {:match, path, match.line, match.col},
      kind: :match,
      label: "#{match.line}  #{match.text}",
      # Where the matched text sits inside `label`, in graphemes — the gutter
      # is the line number plus two spaces, so the offset shifts with it.
      match_start: String.length("#{match.line}  ") + match.match_start,
      match_len: match.match_len,
      path: path,
      line: match.line,
      col: match.col,
      depth: 1,
      actions: [
        {:replace_match, path, match.line, match.col},
        {:dismiss_match, path, match.line, match.col}
      ]
    }
  end

  defp scope_nodes(nodes, state, depth) do
    Enum.flat_map(nodes, fn node ->
      expanded? = MapSet.member?(state.expanded_scope, node.id)
      expandable? = node.children != []
      mark = if node.included?, do: "[x] ", else: "[ ] "

      chevron =
        cond do
          not expandable? -> "  "
          expanded? -> "▾ "
          true -> "▸ "
        end

      row = %{
        id: {:scope, node.id},
        kind: :scope,
        label: chevron <> mark <> node.label,
        path: node.id,
        depth: depth,
        expandable?: expandable?,
        expanded?: expanded?,
        actions: []
      }

      if expanded? do
        [row | scope_nodes(node.children, state, depth + 1)]
      else
        [row]
      end
    end)
  end

  defp scope_summary(scope) do
    excluded = count_excluded(scope)

    if excluded == 0,
      do: "SCOPE  (whole project)",
      else: "SCOPE  (#{excluded} excluded)"
  end

  defp count_excluded(nodes) do
    Enum.reduce(nodes, 0, fn node, acc ->
      acc + if(node.included?, do: 0, else: 1) + count_excluded(node.children)
    end)
  end

  @doc "The rectangles of a row's right-edge action buttons, in content space."
  def action_bounds(%__MODULE__{frame: frame, theme: theme}, row) do
    size = theme.row_height - 4
    right = frame.size.width - theme.padding - 6

    row.actions
    |> Enum.reverse()
    |> Enum.with_index()
    |> Enum.map(fn {action, i} ->
      %{
        action: action,
        x: right - (i + 1) * (size + 4),
        y: row.y + 2,
        w: size,
        h: size
      }
    end)
  end

  # ── Hit testing ───────────────────────────────────────────────────────────

  @doc """
  What is under `{x, y}` (frame-local): a header widget id, a
  `{:row, row, action_or_nil}`, or `nil`.
  """
  def hit_test(%__MODULE__{} = state, {x, y}) do
    if y < header_height(state) do
      Enum.find_value(header_widgets(state), fn w ->
        if inside?(w, x, y), do: w.id
      end)
    else
      body_hit(state, {x, y})
    end
  end

  defp body_hit(%__MODULE__{} = state, {x, y}) do
    content_y = y - header_height(state) + state.scroll.offset_y

    Enum.find_value(rows(state), fn row ->
      if content_y >= row.y and content_y < row.y + row.height do
        action =
          Enum.find_value(action_bounds(state, row), fn b ->
            if x >= b.x and x < b.x + b.w and content_y >= b.y and content_y < b.y + b.h,
              do: b.action
          end)

        {:row, row, action || expander_hit(state, row, x)}
      end
    end)
  end

  # A scope directory carries its own disclosure triangle at the head of the
  # row: the triangle expands, the rest of the row ticks the directory in or
  # out. Ticking is much the commoner action, so it gets the wider target.
  defp expander_hit(%__MODULE__{theme: theme}, %{expandable?: true} = row, x) do
    left = theme.padding + row.depth * theme.indent

    if x >= left and x < left + 16, do: :expand
  end

  defp expander_hit(_state, _row, _x), do: nil

  defp inside?(%{x: bx, y: by, w: bw, h: bh}, x, y),
    do: x >= bx and x < bx + bw and y >= by and y < by + bh

  # ── Fields ────────────────────────────────────────────────────────────────
  #
  # The fields are TextField components. This module remembers WHAT is in them
  # and WHICH one the keyboard belongs to; it no longer implements typing —
  # there used to be a cursor, a backspace, a word-delete and a Home/End here,
  # all of them a worse version of what TextField already did, and none of
  # them offering selection or the clipboard at all.

  def field_value(%__MODULE__{} = state, field) when field in @fields,
    do: Map.fetch!(state, field)

  @doc "Record what a field now contains, as reported by the field itself."
  def put_field_value(%__MODULE__{} = state, field, text)
      when field in @fields and is_binary(text),
      do: Map.put(state, field, text)

  def focus_field(%__MODULE__{} = state, field) when field in @fields,
    do: %{state | focused_field: field}

  def next_field(%__MODULE__{focused_field: field} = state) do
    idx = Enum.find_index(@fields, &(&1 == field))
    %{state | focused_field: Enum.at(@fields, rem(idx + 1, length(@fields)))}
  end

  def prev_field(%__MODULE__{focused_field: field} = state) do
    idx = Enum.find_index(@fields, &(&1 == field))
    %{state | focused_field: Enum.at(@fields, rem(idx - 1 + length(@fields), length(@fields)))}
  end

  # ── Body state ────────────────────────────────────────────────────────────

  def toggle_scope_open(%__MODULE__{} = state),
    do: resync_scroll(%{state | scope_open?: not state.scope_open?})

  def toggle_scope_expand(%__MODULE__{} = state, id) do
    expanded =
      if MapSet.member?(state.expanded_scope, id),
        do: MapSet.delete(state.expanded_scope, id),
        else: MapSet.put(state.expanded_scope, id)

    resync_scroll(%{state | expanded_scope: expanded})
  end

  def toggle_file(%__MODULE__{} = state, path) do
    collapsed =
      if MapSet.member?(state.collapsed_files, path),
        do: MapSet.delete(state.collapsed_files, path),
        else: MapSet.put(state.collapsed_files, path)

    resync_scroll(%{state | collapsed_files: collapsed})
  end

  @doc "Recompute the scrollable content height after the rows changed."
  def resync_scroll(%__MODULE__{} = state) do
    content_height = length(rows(state)) * state.theme.row_height + state.theme.row_height
    body = body_frame(state)

    scroll =
      state.scroll
      |> ScrollState.update_viewport_size(body)
      |> ScrollState.update_content_size(body.size.width, content_height)
      |> show_scrollbar_if_scrollable()

    %{state | scroll: scroll}
  end

  # The pane's scrollbar is a permanent affordance, not a fade-in one: results
  # arrive in a burst and a bar that only appears once you already scrolled
  # cannot tell you there is more below.
  defp show_scrollbar_if_scrollable(scroll) do
    if ScrollState.scrollable_y?(scroll) do
      %{scroll | scrollbar_visible: true, scrollbar_opacity: 255}
    else
      %{scroll | scrollbar_visible: false, scrollbar_opacity: 0}
    end
  end
end
