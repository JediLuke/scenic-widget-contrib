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

  # The scope tree is capped: a project's directories run to hundreds, and a
  # header that grew to that would leave no pane for the results.
  @scope_cap 12

  # Wide enough for two labelled halves at the pane's small type.
  @slider_width 74

  # How many rows either side of the viewport are drawn anyway, so that
  # scrolling a notch does not rebuild the body.
  @overscan 6

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
    # The replacement row, behind a disclosure like the find bar's. Most
    # searches are searches; the replacement field is a second job.
    replace_open?: false,
    # :tree groups matches under their file, :list gives one row per match.
    # Owned by the host, which saves it with its other settings.
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
      results_view: Map.get(model, :results_view, :tree),
      scope: Map.get(model, :scope, []),
      files: Map.get(model, :files, [])
    }
  end

  def put_model(%__MODULE__{} = state, model) do
    normalized = normalize_model(model)

    resync_scroll(%{
      state
      | model: normalized,
        results_view: normalized.results_view,
        expanded_scope: seed_root_expansion(state, normalized)
    })
  end

  # The project row at the top of the scope tree starts OPEN. Shut, the tree
  # is one row naming the directory you are already searching, which tells you
  # nothing and hides everything.
  #
  # Seeded once per project rather than on every snapshot, so that shutting it
  # yourself sticks: results land continuously while you type, and a default
  # reapplied on each one would prise the tree open again under your hand.
  defp seed_root_expansion(
         %__MODULE__{model: %{scope: [%{id: root} | _]}, expanded_scope: expanded},
         %{scope: [%{id: root} | _]}
       ),
       do: expanded

  defp seed_root_expansion(%__MODULE__{expanded_scope: expanded}, %{scope: [%{id: root} | _]}),
    do: MapSet.put(expanded, root)

  defp seed_root_expansion(%__MODULE__{expanded_scope: expanded}, _model), do: expanded

  def put_frame(%__MODULE__{} = state, frame) do
    scroll = ScrollState.update_viewport_size(state.scroll, body_frame(frame, state.theme))
    resync_scroll(%{state | frame: frame, scroll: scroll})
  end

  # ── Geometry ──────────────────────────────────────────────────────────────

  @doc "Height of the fixed header, in pixels."
  # What the header currently IS, which depends on what it is showing: the
  # replacement row and the domain options are both behind disclosures.
  def header_height(%__MODULE__{theme: theme} = state),
    do: status_y(state) + theme.row_height + theme.padding

  # The shut-and-empty height, for callers holding a theme and no state.
  def header_height(theme) do
    pad = theme.padding

    pad + theme.row_height + theme.field_height + 4 + 6 + theme.row_height +
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
    caret_w = 18
    toggle_w = 22
    button_w = 26
    gap = 6

    title_y = pad
    # Air under the title. At one row exactly, the heading's baseline sat four
    # pixels above the field and the two read as one crowded block.
    query_y = title_y + theme.row_height + 8
    replace_y = query_y + fh + 4
    domain_y = replace_y + if(state.replace_open?, do: fh + 10, else: 10)

    # The query field, with its option toggles INSIDE its right-hand end —
    # the same arrangement as the find bar, where it reads that they modify
    # the query rather than the search. They used to sit outside it, which
    # made them look like two more buttons in a row of buttons.
    query_x = pad + caret_w + gap
    query_w = max(width - pad - query_x, 60)
    regex_x = query_x + query_w - 3 - toggle_w
    case_x = regex_x - 2 - toggle_w

    header =
      [
        # A close button the size of the ones on the tabs, with room around it.
        # It was 18px square and unhighlighted — smaller than every other close
        # in the application and easy to miss entirely.
        %{id: :close, x: width - pad - 26, y: title_y - 4, w: 26, h: 26},
        # The disclosure for the replacement row, on the left where a control
        # that opens another row belongs. It spans both rows when open, so its
        # highlight covers what it opened.
        %{
          id: :replace_caret,
          x: pad,
          y: query_y,
          w: caret_w,
          h: if(state.replace_open?, do: 2 * fh + 4, else: fh)
        },
        %{id: {:field, :query}, x: query_x, y: query_y, w: query_w, h: fh},
        %{id: {:toggle, :case_sensitive}, x: case_x, y: query_y + 3, w: toggle_w, h: fh - 6},
        %{id: {:toggle, :regex}, x: regex_x, y: query_y + 3, w: toggle_w, h: fh - 6}
      ] ++
        replace_widgets(state, query_x, replace_y, width, pad, fh, button_w, gap) ++
        [%{id: :domain_header, x: pad, y: domain_y, w: width - 2 * pad, h: theme.row_height}] ++
        domain_widgets(state, domain_y + theme.row_height, width, pad, theme)

    status = status_y(state)
    button = 24

    header ++
      [
        %{
          id: :status,
          x: pad,
          y: status,
          w: max(width - 2 * pad - @slider_width - button - 10, 40),
          h: theme.row_height
        },
        # Tree or list, as ONE control with two positions rather than two
        # buttons: they are not two things you can do, they are two settings
        # of one thing, and a pair of buttons says the first.
        %{
          id: :results_view,
          x: width - pad - button - 6 - @slider_width,
          y: status + 2,
          w: @slider_width,
          h: theme.row_height - 4
        },
        # And a way to put the pane back to empty without hunting for the
        # query field and selecting what is in it.
        %{id: :clear, x: width - pad - button, y: status, w: button, h: theme.row_height}
      ]
  end

  defp replace_widgets(%__MODULE__{replace_open?: false}, _x, _y, _w, _pad, _fh, _bw, _gap),
    do: []

  defp replace_widgets(%__MODULE__{}, query_x, y, width, pad, fh, button_w, gap) do
    all_x = width - pad - button_w
    one_x = all_x - 2 - button_w
    field_w = max(one_x - gap - query_x, 60)

    [
      %{id: {:field, :replace}, x: query_x, y: y, w: field_w, h: fh},
      # Replace this one, and replace all of them — the same pair the find bar
      # offers, because a project replace is the one that most wants doing an
      # occurrence at a time.
      %{id: :replace_one, x: one_x, y: y, w: button_w, h: fh},
      %{id: :replace_all, x: all_x, y: y, w: button_w, h: fh}
    ]
  end

  defp domain_widgets(%__MODULE__{domain_open?: false}, _y, _width, _pad, _theme), do: []

  defp domain_widgets(%__MODULE__{} = state, y, width, pad, theme) do
    row = theme.row_height
    w = width - 2 * pad

    [
      %{id: {:domain, :open_buffers_only}, x: pad, y: y, w: w, h: row},
      %{id: {:domain, :use_ignore_files}, x: pad, y: y + row, w: w, h: row},
      # The excludes list is a file, and this opens it — right here, beside
      # the switch that says whether it is being honoured, rather than buried
      # in a menu three clicks away from the search it governs.
      %{id: :edit_excludes, x: pad, y: y + 2 * row, w: w, h: row}
    ] ++ scope_widgets(state, y + 3 * row, width, pad, theme)
  end

  # The scope tree lives in the settings section, which means the HEADER —
  # above the status line, which is the boundary between the settings and the
  # results. In the body it sat below that line, among the results it is
  # meant to narrow.
  #
  # It is capped: a project's directories can run to hundreds, and a header
  # that grew to that would leave no pane for the results. Past the cap the
  # tree is collapsible — that is what the disclosure triangles are for.
  defp scope_widgets(%__MODULE__{} = state, y, width, pad, theme) do
    rows = state |> scope_rows() |> Enum.take(@scope_cap) |> Enum.with_index()

    row_widgets =
      Enum.map(rows, fn {row, i} ->
        %{
          id: {:scope_row, row.id},
          row: row,
          x: pad,
          y: y + i * theme.row_height,
          w: width - 2 * pad,
          h: theme.row_height
        }
      end)

    # The disclosure triangle is its OWN control, laid over the row's
    # left-hand end — LAST, because `hit_test/2` walks the list backwards and
    # the thing drawn last is the thing on top.
    #
    # Expanding a directory and excluding it are different intentions, and one
    # rectangle cannot carry both. It used to: a scope row whose node had
    # children spent every click on expanding itself, so the one thing a scope
    # tree exists to do — "not that folder" — could not be done to any folder
    # with anything in it. Only empty directories and files could be unticked.
    expanders =
      for {row, i} <- rows, Map.get(row, :expandable?, false) do
        %{
          id: {:scope_expand, row.id},
          row: row,
          x: pad + row.depth * theme.indent,
          y: y + i * theme.row_height,
          w: 16,
          h: theme.row_height
        }
      end

    row_widgets ++ expanders
  end

  @doc "How many rows the settings section adds when it is open."
  def domain_rows(%__MODULE__{domain_open?: true} = state),
    do: 3 + length(Enum.take(scope_rows(state), @scope_cap))

  def domain_rows(%__MODULE__{}), do: 0

  # The status line is the boundary between the controls and the results, so
  # it gets room above it and a rule to sit under — crowded up against the
  # settings it read as one more option.
  defp status_y(%__MODULE__{theme: theme} = state) do
    pad = theme.padding
    fh = theme.field_height

    pad + theme.row_height + 8 + fh + 4 +
      if(state.replace_open?, do: fh + 4, else: 0) +
      10 + theme.row_height +
      domain_rows(state) * theme.row_height + 10
  end

  @doc "Where the rule above the status line goes."
  def status_rule_y(%__MODULE__{theme: theme} = state), do: status_y(state) - 5 + 0 * theme.padding

  @doc """
  The body's rows, in content coordinates.

  Every row carries the actions drawn at its right edge, so the renderer, the
  hit test and the semantic registration cannot disagree about where a button
  is.

  This builds them ALL. Drawing does not go through here — see
  `visible_rows/1` — because a project search returns hundreds and the pane
  shows forty. This is for the callers that genuinely want the whole list.
  """
  def rows(%__MODULE__{} = state), do: rows_window(state, 0, row_count(state))

  @doc """
  The rows the body actually draws: those inside the viewport, plus
  `@overscan` either side.

  Rows are a uniform `theme.row_height`, so which ones those are is
  arithmetic. Nothing outside the window is built, never mind drawn, so a
  five-hundred-match search costs the same to draw as a five-match one — which
  is the whole of why the pane used to stall for a tenth of a second every
  time results landed.
  """
  def visible_rows(%__MODULE__{} = state) do
    {first, count} = visible_window(state)
    rows_window(state, first, count)
  end

  @doc """
  Which rows the body draws, as `{first_index, count}`.

  The overscan is what keeps an ordinary scroll cheap: a wheel notch or two
  lands inside the window that is already drawn, so the body moves by a
  transform and is only rebuilt once the pointer has run past the margin.
  """
  def visible_window(%__MODULE__{theme: theme, scroll: scroll} = state) do
    h = theme.row_height
    total = row_count(state)

    first = max(trunc(scroll.offset_y / h) - @overscan, 0)
    on_screen = ceil(body_frame(state).size.height / h)
    last = min(first + on_screen + 2 * @overscan, total)

    {first, max(last - first, 0)}
  end

  @doc "How many rows the body has, without building a single one of them."
  def row_count(%__MODULE__{} = state),
    do: state |> blocks() |> Enum.reduce(0, fn block, n -> n + block.count end)

  @doc "The row at `index`, or `nil` past the end. What hit testing asks."
  def row_at(%__MODULE__{} = state, index) when index >= 0 do
    case rows_window(state, index, 1) do
      [row] -> row
      [] -> nil
    end
  end

  def row_at(%__MODULE__{}, _index), do: nil

  @doc "Rows `first` up to (not including) `first + count`, and only those."
  def rows_window(%__MODULE__{theme: theme} = state, first, count) do
    h = theme.row_height
    last = first + count

    state
    |> blocks()
    |> Enum.map_reduce(0, fn block, idx ->
      next = idx + block.count

      if idx < last and next > first do
        lo = max(first - idx, 0)
        hi = min(last - idx, block.count)
        {Enum.with_index(block.slice.(lo, hi), idx + lo), next}
      else
        {[], next}
      end
    end)
    |> elem(0)
    |> Enum.concat()
    |> Enum.map(fn {row, i} -> Map.merge(row, %{y: i * h, height: h}) end)
  end

  # One block per file: how many rows it contributes, and a function that
  # builds any sub-range of them. The count is arithmetic, so a file the
  # viewport has scrolled past costs a subtraction rather than a list of
  # match rows — which is what makes `rows_window/3` proportional to the
  # window rather than to the result set.
  #
  # As a TREE: a row per file, with its matches under it, collapsible. As a
  # LIST: a row per match and no file headings, each one carrying its own
  # file name — which is what you want when you are looking for an
  # occurrence rather than for a file.
  defp blocks(%__MODULE__{results_view: :list, model: model}) do
    Enum.map(model.files, fn file ->
      %{
        count: length(file.matches),
        slice: fn lo, hi ->
          file.matches
          |> Enum.slice(lo, hi - lo)
          |> Enum.map(fn match ->
            match
            |> match_row(file.path)
            |> Map.put(:depth, 0)
            |> Map.update!(:label, &"#{file.label}:#{match.line}  #{&1}")
          end)
        end
      }
    end)
  end

  defp blocks(%__MODULE__{model: model} = state) do
    Enum.map(model.files, fn file ->
      collapsed? = MapSet.member?(state.collapsed_files, file.path)

      %{
        count: if(collapsed?, do: 1, else: 1 + length(file.matches)),
        slice: fn lo, hi -> tree_slice(file, collapsed?, lo, hi) end
      }
    end)
  end

  # Local index 0 is the file heading; 1.. are its matches.
  defp tree_slice(file, collapsed?, lo, hi) do
    head = if lo == 0, do: [file_row(file, collapsed?)], else: []

    matches =
      if collapsed? do
        []
      else
        m_lo = max(lo - 1, 0)

        file.matches
        |> Enum.slice(m_lo, max(hi - 1 - m_lo, 0))
        |> Enum.map(&match_row(&1, file.path))
      end

    head ++ matches
  end

  defp file_row(file, collapsed?) do
    %{
      id: {:file, file.path},
      kind: :file,
      label: "#{file.label}  (#{length(file.matches)})",
      path: file.path,
      depth: 0,
      collapsed?: collapsed?,
      actions: [{:replace_file, file.path}, {:dismiss_file, file.path}]
    }
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

  @doc """
  The scope tree's rows — the summary line, and the tree under it when open.

  These are HEADER rows, not body rows: the scope belongs to the settings
  section, above the status line that separates the settings from the
  results.
  """
  def scope_rows(%__MODULE__{domain_open?: false}), do: []

  def scope_rows(%__MODULE__{model: %{scope: []}}), do: []

  def scope_rows(%__MODULE__{model: %{scope: scope}} = state) do
    header = %{
      id: :scope_header,
      kind: :scope_header,
      label: scope_summary(scope),
      # Indented: the scope tree is a section INSIDE the settings, its own
      # dropdown within them, rather than a sibling of the results.
      depth: 1,
      expanded?: state.scope_open?,
      actions: []
    }

    if state.scope_open? do
      [header | scope_nodes(scope, state, 2)]
    else
      [header]
    end
  end

  defp scope_nodes(nodes, state, depth) do
    Enum.flat_map(nodes, fn node ->
      expanded? = MapSet.member?(state.expanded_scope, node.id)
      expandable? = node.children != []
      mark = if node.included?, do: "[x] ", else: "[ ] "

      row = %{
        id: {:scope, node.id},
        kind: :scope,
        # No chevron in the text: it is DRAWN, like the file navigator's. A
        # triangle typed as a character is a triangle the font may not have,
        # and an empty box beside every folder is worse than no triangle.
        label: mark <> node.label,
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

  # The project row is the whole of the scope, so when it is unticked there is
  # nothing to count — saying "1 excluded" would be true and useless.
  defp scope_summary([%{included?: false} | _]), do: "SCOPE  (nothing selected)"

  defp scope_summary(scope) do
    excluded = count_excluded(scope)

    if excluded == 0,
      do: "SCOPE  (whole project)",
      else: "SCOPE  (#{excluded} excluded)"
  end

  # An excluded directory counts ONCE, not once per thing inside it. Exclusion
  # is inherited, so a folder with forty files in it would otherwise report
  # itself as forty-one exclusions for one click.
  defp count_excluded(nodes) do
    Enum.reduce(nodes, 0, fn
      %{included?: false}, acc -> acc + 1
      node, acc -> acc + count_excluded(node.children)
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
      # REVERSE: the list is in drawing order and the thing drawn last is the
      # thing on top. The option toggles sit inside the query field's
      # right-hand end, so a forward search hands every click on them to the
      # field underneath — which is exactly what happened to the find bar
      # when its toggles moved inside its field.
      state
      |> header_widgets()
      |> Enum.reverse()
      |> Enum.find_value(fn w -> if inside?(w, x, y), do: w.id end)
    else
      body_hit(state, {x, y})
    end
  end

  # Which row is under the pointer is arithmetic — the rows are a uniform
  # height — so exactly one row is built to answer it. It used to build every
  # row in the pane and walk them looking for the one it had just computed the
  # index of.
  defp body_hit(%__MODULE__{theme: theme} = state, {x, y}) do
    content_y = y - header_height(state) + state.scroll.offset_y

    case state |> row_at(floor(content_y / theme.row_height)) do
      nil ->
        nil

      row ->
        action =
          Enum.find_value(action_bounds(state, row), fn b ->
            if x >= b.x and x < b.x + b.w and content_y >= b.y and content_y < b.y + b.h,
              do: b.action
          end)

        {:row, row, action || expander_hit(state, row, x)}
    end
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
    content_height = row_count(state) * state.theme.row_height + state.theme.row_height
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
