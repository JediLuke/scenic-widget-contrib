defmodule ScenicWidgets.MenuBar do
  @moduledoc """
  A menu bar component with dropdown menus, following the renderizer pattern.
  This component avoids flickering by pre-rendering all dropdowns and toggling visibility.
  """

  use Scenic.Component, has_children: false
  require Logger

  alias ScenicWidgets.MenuBar.{State, OptimizedRenderizer, Reducer, Api}
  alias Scenic.Graph
  

  def validate(data) when is_map(data) do
    # Required: frame and menu_map
    case {Map.get(data, :frame), Map.get(data, :menu_map)} do
      {%{pin: _, size: _}, menu_map} when is_list(menu_map) ->
        # Convert old format [{:sub_menu, label, items}, ...] to new format
        converted_map = convert_menu_map(menu_map)
        {:ok, Map.put(data, :menu_map, converted_map)}
      {%{pin: _, size: _}, menu_map} when is_map(menu_map) ->
        {:ok, data}
      _ ->
        {:error, "MenuBar requires :frame and :menu_map"}
    end
  end

  # Convert old menu format to new format
  defp convert_menu_map(menu_list) when is_list(menu_list) do
    menu_list
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {item, index}, acc ->
      case item do
        {:sub_menu, label, items} ->
          # Generate unique menu ID based on label and index
          menu_id = String.to_atom("menu_#{index}_#{String.downcase(String.replace(label, " ", "_"))}")
          Map.put(acc, menu_id, {label, items})
        {label, items} when is_binary(label) and is_list(items) ->
          # Also handle simple tuple format
          menu_id = String.to_atom("menu_#{index}_#{String.downcase(String.replace(label, " ", "_"))}")
          Map.put(acc, menu_id, {label, items})
        _ ->
          acc
      end
    end)
  end

  @impl Scenic.Component
  def init(scene, data, _opts) do
    Logger.info("MenuBar init called with data: #{inspect(data)}")

    # Initialize component state
    state = State.new(data)

    # Initial render with all elements pre-rendered
    graph = OptimizedRenderizer.initial_render(Graph.build(), state)

    scene =
      scene
      |> assign(state: state, graph: graph)
      |> push_graph(graph)

    Logger.info("MenuBar initialized successfully")
    
    {:ok, scene}

  end

  # @impl Scenic.Scene
  # def handle_put({:cursor_pos, coords}, scene) do
  #   Logger.debug("MenuBar received cursor_pos via handle_put: #{inspect(coords)}")
  #   state = scene.assigns.state

  #   # Update hover state
  #   new_state = Reducer.handle_cursor_pos(state, coords)

  #   scene = if new_state != state do
  #     Logger.debug("MenuBar state changed: active_menu #{state.active_menu} -> #{new_state.active_menu}")
  #     # Update only changed elements
  #     graph = OptimizedRenderizer.update_render(scene.assigns.graph, state, new_state)

  #     scene
  #     |> assign(state: new_state, graph: graph)
  #     |> push_graph(graph)
  #   else
  #     scene
  #   end

  #   {:noreply, scene}
  # end

  # def handle_put({:click, coords}, scene) do
  #   Logger.debug("MenuBar received click via handle_put: #{inspect(coords)}")
  #   state = scene.assigns.state

  #   # Handle click
  #   scene = case Reducer.handle_click(state, coords) do
  #     {:menu_item_clicked, item_id, new_state} ->
  #       # Send event to parent
  #       send_parent_event(scene, {:menu_item_clicked, item_id})

  #       graph = OptimizedRenderizer.update_render(scene.assigns.graph, state, new_state)

  #       scene
  #       |> assign(state: new_state, graph: graph)
  #       |> push_graph(graph)

  #     {:noop, new_state} ->
  #       graph = OptimizedRenderizer.update_render(scene.assigns.graph, state, new_state)

  #       scene
  #       |> assign(state: new_state, graph: graph)
  #       |> push_graph(graph)
  #   end

  #   {:noreply, scene}
  # end

  def handle_put(:close_all_menus, scene) do
    Logger.debug("MenuBar received :close_all_menus via handle_put")
    state = scene.assigns.state

    # Close all menus
    scene = if state.active_menu do
      new_state = %{state | active_menu: nil, hovered_item: nil, hovered_dropdown: nil, active_sub_menus: %{}}
      graph = OptimizedRenderizer.update_render(scene.assigns.graph, state, new_state)

      scene
      |> assign(state: new_state, graph: graph)
      |> push_graph(graph)
    else
      scene
    end

    {:noreply, scene}
  end

  def handle_put({:set_active_menu, menu_id}, scene) do
    Logger.debug("MenuBar received {:set_active_menu, #{inspect(menu_id)}} via handle_put")
    state = scene.assigns.state
    new_state = Api.set_active_menu(state, menu_id)

    graph = OptimizedRenderizer.update_render(scene.assigns.graph, state, new_state)

    scene =
      scene
      |> assign(state: new_state, graph: graph)
      |> push_graph(graph)

    {:noreply, scene}
  end

  def handle_put(_value, scene) do
    # Ignore unknown values
    {:noreply, scene}
  end

  def handle_input({:cursor_pos, coords}, _context, scene) do
    state = scene.assigns.state
    new_state = Reducer.handle_cursor_pos(state, coords)

    if new_state != state do
      graph = OptimizedRenderizer.update_render(scene.assigns.graph, state, new_state)
      scene = scene
      |> assign(state: new_state, graph: graph)
      |> push_graph(graph)
      {:noreply, scene}
    else
      {:noreply, scene}
    end
  end

  def handle_input({:cursor_button, {:btn_left, 1, [], coords}}, _context, scene) do
    Logger.debug("MenuBar handle_input click received at: #{inspect(coords)}")
    state = scene.assigns.state

    case Reducer.handle_click(state, coords) do
      {:menu_item_clicked, item_id, new_state} ->
        # Send event to parent
        send_parent_event(scene, {:menu_item_clicked, item_id})
        
        # Update the graph
        graph = OptimizedRenderizer.update_render(scene.assigns.graph, state, new_state)
        scene = scene
        |> assign(state: new_state, graph: graph)
        |> push_graph(graph)
        {:noreply, scene}

      {:noop, new_state} ->
        graph = OptimizedRenderizer.update_render(scene.assigns.graph, state, new_state)
        scene = scene
        |> assign(state: new_state, graph: graph)
        |> push_graph(graph)
        {:noreply, scene}
    end
  end

  def handle_input({:key, {:key_escape, 1, _}}, _context, scene) do
    state = scene.assigns.state
    new_state = Reducer.handle_escape(state)

    if new_state != state do
      graph = OptimizedRenderizer.update_render(scene.assigns.graph, state, new_state)
      scene = scene
      |> assign(state: new_state, graph: graph)
      |> push_graph(graph)
      {:noreply, scene}
    else
      {:noreply, scene}
    end
  end

  def handle_input(_input, _context, scene) do
    {:noreply, scene}
  end

  # Remove handle_cast - we're using handle_put for state updates now
end
