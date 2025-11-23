defmodule ScenicWidgets.SideNav do
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
    # Logger.info("🎯 SideNav component initializing")

    # Initialize component state
    state = State.new(data)

    # Initial render
    graph = Renderizer.initial_render(Graph.build(), state)

    scene =
      scene
      |> assign(state: state, graph: graph)
      |> push_graph(graph)

    # Register semantic elements for MCP interaction
    register_semantic_elements(scene, state)

    # Logger.info("SideNav initialized successfully")

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
    state = scene.assigns.state

    case Reducer.handle_click(state, coords) do
      {:navigate, item_id, new_state} ->
        # Send navigation event to parent
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

      {:noop, new_state} ->
        graph = Renderizer.update_render(scene.assigns.graph, state, new_state)

        scene =
          scene
          |> assign(state: new_state, graph: graph)
          |> push_graph(graph)

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
  defp register_semantic_elements(scene, %State{} = state) do
    viewport = scene.viewport
    graph_key = scene.assigns[:id] || :side_nav

    # Register each visible item as a clickable semantic element
    state.item_bounds
    |> Enum.each(fn {item_id, bounds} ->
      item = Item.find_by_id(state.tree, item_id)

      if item do
        # Create semantic ID
        semantic_id = String.to_atom("sidebar_item_#{item_id}")

        # TODO: Re-enable when Scenic.ViewPort.register_semantic/4 is available
        # Scenic.ViewPort.register_semantic(
        #   viewport,
        #   graph_key,
        #   semantic_id,
        #   %{
        #     type: :list_item,
        #     label: Item.get_title(item),
        #     clickable: true,
        #     bounds: %{
        #       left: bounds.x,
        #       top: bounds.y,
        #       width: bounds.width,
        #       height: bounds.height
        #     }
        #   }
        # )
      end
    end)

    :ok
  end
end
