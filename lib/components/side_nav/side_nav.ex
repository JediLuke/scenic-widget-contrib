defmodule ScenicWidgets.SideNav do
  IO.puts("⚡⚡⚡ SideNav module being compiled/loaded! ⚡⚡⚡")

  @moduledoc """
  A hierarchical sidebar navigation component following HexDocs style.

  ## Features
  - Expandable/collapsible tree structure
  - Click chevron to expand/collapse
  - Click text to navigate (emits events)
  - Full keyboard navigation (arrows, enter, home/end)
  - Active item highlighting with accent bar
  - Hover states
  - Focus ring for keyboard navigation
  - Smooth scrolling
  - MCP semantic element registration

  ## Usage

      tree = [
        %SideNav.Item{
          id: "getting_started",
          title: "GETTING STARTED",
          type: :group,
          children: [
            %SideNav.Item{
              id: "intro",
              title: "Introduction",
              type: :page,
              url: "/intro"
            }
          ]
        }
      ]

      graph
      |> SideNav.add_to_graph(
        %{
          frame: frame,
          tree: tree,
          active_id: "intro"
        },
        id: :sidebar
      )

  ## Events

  SideNav sends these events to the parent scene:
  - `{:sidebar, :navigate, item_id}` - When an item is clicked or Enter pressed
  - `{:sidebar, :expand, item_id}` - When a node is expanded
  - `{:sidebar, :collapse, item_id}` - When a node is collapsed
  - `{:sidebar, :hover, item_id}` - When mouse hovers over an item
  """

  use Scenic.Component, has_children: false
  require Logger

  alias ScenicWidgets.SideNav.{State, Renderizer, Reducer, Api, Item}
  alias Scenic.Graph

  # Override add_to_graph to add logging
  def add_to_graph(graph, data, opts \\ []) do
    IO.puts("🎯🎯🎯 SideNav.add_to_graph called!")
    IO.puts("   data: #{inspect(data)}")
    IO.puts("   opts: #{inspect(opts)}")
    # Call the default implementation provided by `use Scenic.Component`
    super(graph, data, opts)
  end

  @doc """
  Validate initialization data.
  """
  def validate(data) when is_map(data) do
    case {Map.get(data, :frame), Map.get(data, :tree)} do
      {%{pin: _, size: _}, tree} when is_list(tree) ->
        {:ok, data}

      {%{pin: _, size: _}, nil} ->
        # No tree provided, use test tree
        {:ok, Map.put(data, :tree, Item.test_tree())}

      _ ->
        {:error, "SideNav requires :frame and :tree"}
    end
  end

  @impl Scenic.Component
  def init(scene, data, _opts) do
    IO.puts("🎯🎯🎯 SideNav.init called!!!")
    Logger.info("🎯 SideNav component initializing!")

    # Initialize component state
    state = State.new(data)

    IO.puts("   State created with #{map_size(state.item_bounds)} item bounds")
    Logger.info("   State created with #{map_size(state.item_bounds)} item bounds")

    # Initial render
    graph = Renderizer.initial_render(Graph.build(), state)

    scene =
      scene
      |> assign(state: state, graph: graph)
      |> push_graph(graph)

    # Request input events for mouse interaction
    request_input(scene, [:cursor_button, :cursor_pos, :cursor_scroll, :key])

    Logger.info("   Graph pushed, now calling register_semantic_elements...")
    # Register semantic elements for MCP interaction
    register_semantic_elements(scene, state)

    Logger.info("✅ SideNav initialized successfully")

    {:ok, scene}
  end

  @impl Scenic.Scene
  def handle_put({:set_active, item_id}, scene) do
    state = scene.assigns.state
    new_state = Api.set_active(state, item_id)

    graph = Renderizer.update_render(scene.assigns.graph, state, new_state)

    scene =
      scene
      |> assign(state: new_state, graph: graph)
      |> push_graph(graph)

    {:noreply, scene}
  end

  def handle_put({:toggle_expand, item_id}, scene) do
    state = scene.assigns.state
    new_state = Api.toggle_expand(state, item_id)

    graph = Renderizer.update_render(scene.assigns.graph, state, new_state)

    scene =
      scene
      |> assign(state: new_state, graph: graph)
      |> push_graph(graph)

    {:noreply, scene}
  end

  def handle_put({:update_tree, new_tree}, scene) do
    state = scene.assigns.state
    new_state = Api.update_tree(state, new_tree)

    # Full re-render for tree changes
    graph = Renderizer.initial_render(Graph.build(), new_state)

    scene =
      scene
      |> assign(state: new_state, graph: graph)
      |> push_graph(graph)

    {:noreply, scene}
  end

  def handle_put({:set_filter, filter_term}, scene) do
    state = scene.assigns.state
    new_state = Api.set_filter(state, filter_term)

    # Full re-render for filtered tree
    graph = Renderizer.initial_render(Graph.build(), new_state)

    scene =
      scene
      |> assign(state: new_state, graph: graph)
      |> push_graph(graph)

    {:noreply, scene}
  end

  def handle_put(_value, scene) do
    {:noreply, scene}
  end

  @impl Scenic.Scene
  def handle_input({:cursor_pos, coords}, _context, scene) do
    state = scene.assigns.state
    new_state = Reducer.handle_cursor_pos(state, coords)

    if new_state != state do
      graph = Renderizer.update_render(scene.assigns.graph, state, new_state)

      scene =
        scene
        |> assign(state: new_state, graph: graph)
        |> push_graph(graph)

      {:noreply, scene}
    else
      {:noreply, scene}
    end
  end

  def handle_input({:cursor_button, {:btn_left, 1, [], coords}}, _context, scene) do
    Logger.info("🖱️ SideNav received click at #{inspect(coords)}")
    state = scene.assigns.state

    case Reducer.handle_click(state, coords) do
      {:navigate, item_id, new_state} ->
        # Find the item to check if it has an action callback
        item = Item.find_by_id(state.tree, item_id)
        action = Item.get_action(item)

        # Log what we're doing
        Logger.info("📍 LEAF CLICKED: #{item_id}")

        # Send navigation event to parent (ALWAYS happens)
        Logger.info("   📤 Sending parent message: {:sidebar, :navigate, #{inspect(item_id)}}")
        send_parent_event(scene, {:sidebar, :navigate, item_id})

        # Execute action callback if present (OPTIONAL)
        if action do
          Logger.info("   🔥 Executing action callback for #{item_id}")
          action.()
        else
          Logger.info("   ℹ️  No action callback - parent message only")
        end

        graph = Renderizer.update_render(scene.assigns.graph, state, new_state)

        scene =
          scene
          |> assign(state: new_state, graph: graph)
          |> push_graph(graph)

        {:noreply, scene}

      {:noop, new_state} ->
        graph = Renderizer.update_render(scene.assigns.graph, state, new_state)

        scene =
          scene
          |> assign(state: new_state, graph: graph)
          |> push_graph(graph)

        # Re-register semantic elements if expansion state changed
        if state.expanded != new_state.expanded do
          register_semantic_elements(scene, new_state)
        end

        {:noreply, scene}
    end
  end

  def handle_input({:cursor_scroll, {_dx, _dy} = delta}, _context, scene) do
    state = scene.assigns.state
    new_state = Reducer.handle_scroll(state, delta)

    graph = Renderizer.update_render(scene.assigns.graph, state, new_state)

    scene =
      scene
      |> assign(state: new_state, graph: graph)
      |> push_graph(graph)

    {:noreply, scene}
  end

  # Keyboard navigation
  def handle_input({:key, {:key_down, 1, _}}, _context, scene) do
    handle_keyboard(scene, &Reducer.handle_key_down/1)
  end

  def handle_input({:key, {:key_up, 1, _}}, _context, scene) do
    handle_keyboard(scene, &Reducer.handle_key_up/1)
  end

  def handle_input({:key, {:key_left, 1, _}}, _context, scene) do
    handle_keyboard(scene, &Reducer.handle_key_left/1)
  end

  def handle_input({:key, {:key_right, 1, _}}, _context, scene) do
    handle_keyboard(scene, &Reducer.handle_key_right/1)
  end

  def handle_input({:key, {:key_enter, 1, _}}, _context, scene) do
    state = scene.assigns.state

    case Reducer.handle_key_enter(state) do
      {:navigate, item_id, new_state} ->
        send_parent_event(scene, {:sidebar, :navigate, item_id})

        # Execute action callback if present
        item = Item.find_by_id(state.tree, item_id)
        if action = Item.get_action(item) do
          action.()
        end

        graph = Renderizer.update_render(scene.assigns.graph, state, new_state)

        scene =
          scene
          |> assign(state: new_state, graph: graph)
          |> push_graph(graph)

        {:noreply, scene}

      {:noop, _} ->
        {:noreply, scene}
    end
  end

  def handle_input({:key, {:key_home, 1, _}}, _context, scene) do
    handle_keyboard(scene, &Reducer.handle_key_home/1)
  end

  def handle_input({:key, {:key_end, 1, _}}, _context, scene) do
    handle_keyboard(scene, &Reducer.handle_key_end/1)
  end

  def handle_input({:key, {:key_escape, 1, _}}, _context, scene) do
    handle_keyboard(scene, &Reducer.handle_key_escape/1)
  end

  def handle_input(_input, _context, scene) do
    {:noreply, scene}
  end

  # Helper for keyboard input handling
  defp handle_keyboard(scene, reducer_fn) do
    state = scene.assigns.state
    new_state = reducer_fn.(state)

    if new_state != state do
      graph = Renderizer.update_render(scene.assigns.graph, state, new_state)

      scene =
        scene
        |> assign(state: new_state, graph: graph)
        |> push_graph(graph)

      {:noreply, scene}
    else
      {:noreply, scene}
    end
  end

  # Register semantic elements for MCP interaction
  # Manually registers elements into Phase 1 semantic tables
  # (Phase 1 doesn't handle component sub-scenes automatically)
  defp register_semantic_elements(scene, %State{} = state) do
    viewport = scene.viewport
    scene_name = scene.assigns[:id] || :side_nav

    # Get the component's screen position from frame.pin
    {offset_x, offset_y} = state.frame.pin.point

    Logger.info("🔍 SideNav attempting semantic registration...")
    Logger.info("   Viewport has semantic_table? #{inspect(!!viewport.semantic_table)}")
    Logger.info("   Semantic enabled? #{inspect(viewport.semantic_enabled)}")
    Logger.info("   Component offset: (#{offset_x}, #{offset_y})")
    Logger.info("   Item bounds count: #{inspect(map_size(state.item_bounds))}")

    # Only register if semantic tables are available
    if viewport.semantic_table && viewport.semantic_enabled do
      # Register chevrons and text for each visible item
      state.item_bounds
      |> Enum.each(fn {item_id, bounds} ->
        item = Item.find_by_id(state.tree, item_id)

        if item do
          has_children = Item.has_children?(item)
          theme = state.theme

          # Calculate positions matching render_item logic
          depth = bounds.depth
          indent_x = theme.padding_left + (depth * theme.indent)
          chevron_area_width = theme.chevron_size + theme.chevron_margin

          # Register chevron (if item has children)
          if has_children do
            chevron_id = String.to_atom("chevron_#{item_id}")

            # Local bounds (within component)
            local_left = indent_x
            local_top = bounds.y

            # Screen bounds (add component offset)
            screen_left = offset_x + local_left
            screen_top = offset_y + local_top

            chevron_entry = %Scenic.Semantic.Compiler.Entry{
              id: chevron_id,
              type: :button,
              module: nil,
              parent_id: nil,
              children: [],
              local_bounds: %{left: local_left, top: local_top, width: theme.chevron_size, height: theme.item_height},
              screen_bounds: %{left: screen_left, top: screen_top, width: theme.chevron_size, height: theme.item_height},
              clickable: true,
              focusable: false,
              label: "Chevron for #{Item.get_title(item)}",
              role: :toggle,
              value: nil,
              hidden: false,
              z_index: 0
            }
            :ets.insert(viewport.semantic_table, {{scene_name, chevron_id}, chevron_entry})
            :ets.insert(viewport.semantic_index, {chevron_id, {scene_name, chevron_id}})
            Logger.info("     ✅ Registered chevron: #{chevron_id} at screen (#{screen_left}, #{screen_top})")
          end

          # Register item text
          text_id = String.to_atom("item_text_#{item_id}")

          # Text starts after chevron area
          local_text_left = indent_x + chevron_area_width
          local_text_top = bounds.y
          text_width = bounds.width - chevron_area_width

          # Screen bounds
          screen_text_left = offset_x + local_text_left
          screen_text_top = offset_y + local_text_top

          text_entry = %Scenic.Semantic.Compiler.Entry{
            id: text_id,
            type: :text,
            module: nil,
            parent_id: nil,
            children: [],
            local_bounds: %{left: local_text_left, top: local_text_top, width: text_width, height: theme.item_height},
            screen_bounds: %{left: screen_text_left, top: screen_text_top, width: text_width, height: theme.item_height},
            clickable: true,
            focusable: false,
            label: Item.get_title(item),
            role: :link,
            value: nil,
            hidden: false,
            z_index: 0
          }
          :ets.insert(viewport.semantic_table, {{scene_name, text_id}, text_entry})
          :ets.insert(viewport.semantic_index, {text_id, {scene_name, text_id}})
        end
      end)

      Logger.info("✅ SideNav semantic registration complete!")
    else
      Logger.warning("⚠️  SideNav semantic registration skipped - semantic tables not available")
    end

    :ok
  end
end
