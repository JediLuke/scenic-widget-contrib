defmodule ScenicWidgets.SearchPane do
  @moduledoc """
  A project-search pane: query, replacement and exclude fields over a
  scrollable list of matches grouped by file.

  It is generic over its data the way `SideNav` and `TabBar` are. The pane
  owns the three text fields and everything about how results are *presented*
  — which files are collapsed, what the pointer is over, where the scroll sits.
  It owns nothing about what a search *means*: the parent supplies results and
  performs every action the pane asks for.

  ## Data

      %{
        frame: %Widgex.Frame{},
        theme: %{},              # optional, merged over State.default_theme/0
        query: "needle",         # optional initial field contents
        replace: "",
        exclude: "",
        model: %{
          status: :idle | :searching | {:done, matches, files, ms} | {:error, term},
          error: nil | String.t(),          # e.g. a regex that does not compile
          case_sensitive: boolean(),
          regex: boolean(),
          scope: [scope_node],
          files: [file_group]
        }
      }

      scope_node: %{id: term, label: String.t(), included?: boolean(), children: [scope_node]}
      file_group: %{path: term, label: String.t(), matches: [match]}
      match:      %{line: pos_integer(), col: pos_integer(), text: String.t(),
                    match_start: non_neg_integer(), match_len: non_neg_integer()}

  `match_start` is a 0-based grapheme offset into `text`. Keeping it — rather
  than handing over a pre-flattened string — is what lets a row mark the
  matched text inside the line.

  ## Events

  All events are `{:search_pane, ...}` tuples sent to the parent scene:

  - `{:search_pane, :close}`
  - `{:search_pane, :query_changed, query}`
  - `{:search_pane, :exclude_changed, glob}`
  - `{:search_pane, :toggle_option, :case_sensitive | :regex}`
  - `{:search_pane, :toggle_scope, id}`
  - `{:search_pane, :open_match, path, line, col}`
  - `{:search_pane, :dismiss_match, path, line, col}`
  - `{:search_pane, :dismiss_file, path}`
  - `{:search_pane, :replace_match, path, line, col, replacement}`
  - `{:search_pane, :replace_file, path, replacement}`
  - `{:search_pane, :replace_all, replacement}`

  ## Messages in

  - `{:update_model, model}` — new results, status or options
  - `{:update_frame, frame}`
  - `{:set_query, query}` — set the query field from outside (e.g. the word
    under the cursor when the pane is opened)
  - `{:focus_field, :query | :replace | :exclude}`
  - `{:set_theme, theme}` — repaint, merging over the current theme
  - `:focus` / `:blur` — keyboard focus, granted by the parent
  """

  use Scenic.Component, has_children: false
  require Logger

  alias ScenicWidgets.SearchPane.{Renderizer, State}
  alias Widgex.Scroll.{ScrollReducer, ScrollState}

  @key_pressed 1

  @impl Scenic.Component
  def validate(%{frame: %{pin: _, size: _}} = data), do: {:ok, data}
  def validate(_data), do: {:error, "SearchPane requires :frame"}

  @impl Scenic.Scene
  def init(scene, data, _opts) do
    state = State.new(data)
    graph = Renderizer.render(state)

    scene =
      scene
      |> assign(state: state, graph: graph, id: :search_pane)
      |> push_graph(graph)

    # Keyboard for the fields, scroll for the results. Clicks arrive through
    # the background primitive's `input:` list — requesting :cursor_button here
    # as well would deliver every press twice.
    request_input(scene, [:key, :codepoint, :cursor_scroll])
    register_semantic_elements(scene, state)

    {:ok, scene}
  end

  # ── Messages from the parent ──────────────────────────────────────────────

  @doc """
  New params from the parent's graph.

  Defining this at all is the point: without it Scenic re-runs `init/3` on the
  same process, which re-requests keyboard input and re-seeds the fields — the
  observed symptom was every character arriving twice, and the query field
  reading "needleneedle".

  The fields are deliberately NOT taken from the params. The pane owns them;
  the parent seeds them once at creation and sets them explicitly afterwards
  with `{:set_query, _}`.
  """
  @impl Scenic.Scene
  def handle_update(data, _opts, scene) do
    state =
      scene.assigns.state
      |> State.put_model(Map.get(data, :model, %{}))
      |> State.put_frame(data.frame)

    {:ok, redraw(scene, state)}
  end

  @impl Scenic.Scene
  def handle_put({:update_model, model}, scene) do
    {:noreply, redraw(scene, State.put_model(scene.assigns.state, model))}
  end

  def handle_put({:update_frame, frame}, scene) do
    {:noreply, redraw(scene, State.put_frame(scene.assigns.state, frame))}
  end

  def handle_put({:set_theme, theme}, scene) when is_map(theme) do
    state = scene.assigns.state
    {:noreply, redraw(scene, State.resync_scroll(%{state | theme: Map.merge(state.theme, theme)}))}
  end

  def handle_put({:set_query, query}, scene) do
    state = scene.assigns.state

    new_state = %{
      state
      | query: query,
        cursors: Map.put(state.cursors, :query, String.length(query)),
        focused_field: :query,
        replace_query_on_input: query != ""
    }

    {:noreply, redraw(scene, new_state)}
  end

  def handle_put({:focus_field, field}, scene) do
    {:noreply, redraw(scene, State.focus_field(scene.assigns.state, field))}
  end

  def handle_put(:focus, scene) do
    {:noreply, redraw(scene, %{scene.assigns.state | focused: true})}
  end

  def handle_put(:blur, scene) do
    {:noreply, redraw(scene, %{scene.assigns.state | focused: false})}
  end

  def handle_put(_value, scene), do: {:noreply, scene}

  # ── Input ─────────────────────────────────────────────────────────────────

  @impl Scenic.Scene
  def handle_input({:cursor_button, {:btn_left, 1, _mods, coords}}, _context, scene) do
    click(scene, coords)
  end

  def handle_input({:cursor_pos, coords}, _context, scene) do
    hover(scene, coords)
  end

  # Scenic reports the wheel in two shapes depending on driver; both mean the
  # same thing here.
  def handle_input({:cursor_scroll, {{_dx, dy}, {x, y}}}, _context, scene),
    do: wheel(scene, dy, {x, y})

  def handle_input({:cursor_scroll, {_dx, dy, x, y}}, _context, scene),
    do: wheel(scene, dy, {x, y})

  # Keyboard belongs to the fields, and only while the parent has given the
  # pane focus — otherwise typing in the editor would also edit the query.
  def handle_input({:codepoint, {char, _}}, _context, %{assigns: %{state: %{focused: true}}} = scene)
      when char != "" do
    state = State.insert_char(scene.assigns.state, char)
    {:noreply, scene |> redraw(state) |> announce_field(state)}
  end

  def handle_input({:key, {key, @key_pressed, mods}}, _context, %{assigns: %{state: %{focused: true}}} = scene) do
    key_press(scene, key, mods)
  end

  def handle_input(_input, _context, scene), do: {:noreply, scene}

  defp wheel(scene, dy, {x, y}) do
    state = scene.assigns.state

    if inside_frame?(state, {x, y}) do
      new_state = %{state | scroll: ScrollReducer.handle_wheel(state.scroll, dy)}
      graph = Renderizer.scroll_to(scene.assigns.graph, state, new_state)

      scene = scene |> assign(state: new_state, graph: graph) |> push_graph(graph)
      register_semantic_elements(scene, new_state)
      {:noreply, scene}
    else
      {:noreply, scene}
    end
  end

  defp key_press(scene, :key_tab, mods) do
    state = scene.assigns.state

    new_state =
      if :shift in mods, do: State.prev_field(state), else: State.next_field(state)

    {:noreply, redraw(scene, new_state)}
  end

  defp key_press(scene, :key_backspace, _mods) do
    state = State.backspace(scene.assigns.state)
    {:noreply, scene |> redraw(state) |> announce_field(state)}
  end

  defp key_press(scene, :key_delete, _mods) do
    state = State.delete(scene.assigns.state)
    {:noreply, scene |> redraw(state) |> announce_field(state)}
  end

  defp key_press(scene, :key_left, _mods),
    do: {:noreply, redraw(scene, State.cursor_left(scene.assigns.state))}

  defp key_press(scene, :key_right, _mods),
    do: {:noreply, redraw(scene, State.cursor_right(scene.assigns.state))}

  defp key_press(scene, :key_home, _mods),
    do: {:noreply, redraw(scene, State.cursor_home(scene.assigns.state))}

  defp key_press(scene, :key_end, _mods),
    do: {:noreply, redraw(scene, State.cursor_end(scene.assigns.state))}

  # Enter in the replacement field means "replace everything", which is the
  # only destructive thing the pane can do from the keyboard; from the query
  # field it means nothing, because the search already ran as you typed.
  defp key_press(scene, :key_enter, _mods) do
    state = scene.assigns.state

    if state.focused_field == :replace do
      send_parent_event(scene, {:search_pane, :replace_all, state.replace})
    end

    {:noreply, scene}
  end

  defp key_press(scene, :key_esc, _mods) do
    send_parent_event(scene, {:search_pane, :close})
    {:noreply, scene}
  end

  defp key_press(scene, _key, _mods), do: {:noreply, scene}

  # A field's contents changed: tell the parent, but only for the two fields
  # that steer the search. The replacement is carried on the action instead —
  # it must not re-run anything by being typed.
  defp announce_field(scene, %State{focused_field: :query} = state) do
    send_parent_event(scene, {:search_pane, :query_changed, state.query})
    scene
  end

  defp announce_field(scene, %State{focused_field: :exclude} = state) do
    send_parent_event(scene, {:search_pane, :exclude_changed, state.exclude})
    scene
  end

  defp announce_field(scene, _state), do: scene

  # ── Pointer ───────────────────────────────────────────────────────────────

  defp click(scene, coords) do
    state = scene.assigns.state

    case State.hit_test(state, coords) do
      nil ->
        {:noreply, scene}

      :close ->
        send_parent_event(scene, {:search_pane, :close})
        {:noreply, scene}

      :status ->
        {:noreply, scene}

      :replace_all ->
        send_parent_event(scene, {:search_pane, :replace_all, state.replace})
        {:noreply, scene}

      {:field, field} ->
        {:noreply, redraw(scene, State.focus_field(State.keep_seeded_query(state), field))}

      {:toggle, option} ->
        send_parent_event(scene, {:search_pane, :toggle_option, option})
        {:noreply, scene}

      {:row, row, nil} ->
        row_click(scene, state, row)

      {:row, row, :expand} ->
        {:noreply, redraw(scene, State.toggle_scope_expand(state, row.path))}

      {:row, _row, action} ->
        act(scene, state, action)
    end
  end

  defp row_click(scene, state, %{kind: :scope_header}),
    do: {:noreply, redraw(scene, State.toggle_scope_open(state))}

  # A scope row is a checkbox with a disclosure triangle sharing one line: the
  # left edge expands, the rest ticks. Clicking the label to toggle inclusion
  # is the common case, so it gets the larger target.
  defp row_click(scene, _state, %{kind: :scope} = row) do
    send_parent_event(scene, {:search_pane, :toggle_scope, row.path})
    {:noreply, scene}
  end

  defp row_click(scene, state, %{kind: :file} = row),
    do: {:noreply, redraw(scene, State.toggle_file(state, row.path))}

  defp row_click(scene, _state, %{kind: :match} = row) do
    send_parent_event(scene, {:search_pane, :open_match, row.path, row.line, row.col})
    {:noreply, scene}
  end

  defp act(scene, state, {:replace_file, path}) do
    send_parent_event(scene, {:search_pane, :replace_file, path, state.replace})
    {:noreply, scene}
  end

  defp act(scene, state, {:replace_match, path, line, col}) do
    send_parent_event(scene, {:search_pane, :replace_match, path, line, col, state.replace})
    {:noreply, scene}
  end

  defp act(scene, _state, {:dismiss_file, path}) do
    send_parent_event(scene, {:search_pane, :dismiss_file, path})
    {:noreply, scene}
  end

  defp act(scene, _state, {:dismiss_match, path, line, col}) do
    send_parent_event(scene, {:search_pane, :dismiss_match, path, line, col})
    {:noreply, scene}
  end

  defp hover(scene, coords) do
    state = scene.assigns.state

    hovered =
      case State.hit_test(state, coords) do
        {:row, row, _action} -> row.id
        _other -> nil
      end

    if hovered == state.hovered do
      {:noreply, scene}
    else
      {:noreply, redraw(scene, %{state | hovered: hovered})}
    end
  end

  defp inside_frame?(%State{frame: frame}, {x, y}) do
    {px, py} = frame.pin.point
    x >= px and x <= px + frame.size.width and y >= py and y <= py + frame.size.height
  end

  # ── Plumbing ──────────────────────────────────────────────────────────────

  defp redraw(scene, state) do
    graph = Renderizer.render(state)

    scene = scene |> assign(state: state, graph: graph) |> push_graph(graph)
    register_semantic_elements(scene, state)
    scene
  end

  # Everything the pane draws is published to the semantic layer under a
  # printable id, so a test (or any other tool) can click a row or a button by
  # name rather than by guessing at coordinates.
  defp register_semantic_elements(scene, %State{} = state) do
    viewport = scene.viewport

    if viewport.semantic_table && viewport.semantic_enabled do
      {pin_x, pin_y} = state.frame.pin.point
      header_h = State.header_height(state)
      {_tx, ty} = ScrollState.translate_offset(state.scroll)

      header =
        Enum.map(State.header_widgets(state), fn w ->
          {semantic_id(w.id), w.x, w.y, w.w, w.h, header_label(w.id, state)}
        end)

      body =
        Enum.flat_map(State.rows(state), fn row ->
          row_entry =
            {semantic_id(row.id), 0, header_h + ty + row.y, state.frame.size.width, row.height,
             row.label}

          actions =
            Enum.map(State.action_bounds(state, row), fn b ->
              {semantic_id(b.action), b.x, header_h + ty + b.y, b.w, b.h,
               action_label(b.action)}
            end)

          [row_entry | actions]
        end)

      :ets.match_delete(viewport.semantic_table, {{:search_pane, :_}, :_})
      :ets.match_delete(viewport.semantic_index, {:_, {:search_pane, :_}})

      Enum.each(header ++ body, fn {id, x, y, w, h, label} ->
        entry = %Scenic.Semantic.Compiler.Entry{
          id: id,
          type: :button,
          module: nil,
          parent_id: nil,
          children: [],
          local_bounds: %{left: x, top: y, width: w, height: h},
          screen_bounds: %{left: pin_x + x, top: pin_y + y, width: w, height: h},
          clickable: true,
          focusable: false,
          label: label,
          role: :button,
          value: nil,
          hidden: false,
          z_index: 0
        }

        :ets.insert(viewport.semantic_table, {{:search_pane, id}, entry})
        :ets.insert(viewport.semantic_index, {id, {:search_pane, id}})
      end)
    end

    :ok
  end

  defp semantic_id(:close), do: :search_pane_close
  defp semantic_id(:replace_all), do: :search_pane_replace_all
  defp semantic_id(:status), do: :search_pane_status
  defp semantic_id(:scope_header), do: :search_pane_scope
  defp semantic_id({:field, field}), do: :"search_pane_field_#{field}"
  defp semantic_id({:toggle, option}), do: :"search_pane_toggle_#{option}"
  defp semantic_id({:scope, id}), do: :"search_pane_scope_#{id}"
  defp semantic_id(:expand), do: :search_pane_expand
  defp semantic_id({:file, path}), do: :"search_pane_file_#{path}"
  defp semantic_id({:match, path, line, col}), do: :"search_pane_match_#{line}_#{col}_#{path}"
  defp semantic_id({:dismiss_file, path}), do: :"search_pane_dismiss_file_#{path}"
  defp semantic_id({:replace_file, path}), do: :"search_pane_replace_file_#{path}"

  defp semantic_id({:dismiss_match, path, line, col}),
    do: :"search_pane_dismiss_match_#{line}_#{col}_#{path}"

  defp semantic_id({:replace_match, path, line, col}),
    do: :"search_pane_replace_match_#{line}_#{col}_#{path}"

  defp header_label({:field, field}, state), do: State.field_value(state, field)
  defp header_label(:close, _state), do: "Close project search"
  defp header_label(:replace_all, _state), do: "Replace all"
  defp header_label({:toggle, :case_sensitive}, _state), do: "Match case"
  defp header_label({:toggle, :regex}, _state), do: "Regular expression"
  defp header_label(:status, _state), do: "Search status"

  defp action_label({:replace_file, path}), do: "Replace all in #{path}"
  defp action_label({:dismiss_file, path}), do: "Dismiss #{path}"
  defp action_label({:replace_match, _path, line, col}), do: "Replace match #{line}:#{col}"
  defp action_label({:dismiss_match, _path, line, col}), do: "Dismiss match #{line}:#{col}"
end
