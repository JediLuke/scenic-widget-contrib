defmodule WidgetWorkbench.Components.MenuBar do
  @moduledoc """
  A menu bar component with dropdown menus, following the renderizer pattern.
  This component avoids flickering by pre-rendering all dropdowns and toggling visibility.
  """
  
  use Scenic.Component
  require Logger
  
  alias WidgetWorkbench.Components.MenuBar.{State, OptimizedRenderizer, Reducer, Api}
  alias Scenic.Graph
  
  @impl Scenic.Component
  def validate(data) when is_map(data) do
    # Required: frame and menu_map
    case {Map.get(data, :frame), Map.get(data, :menu_map)} do
      {%{pin: _, size: _}, menu_map} when is_map(menu_map) ->
        {:ok, data}
      _ ->
        {:error, "MenuBar requires :frame and :menu_map"}
    end
  end
  
  @impl Scenic.Scene
  def init(scene, data, _opts) do
    # Initialize component state
    state = State.new(data)
    
    # Initial render with all elements pre-rendered
    graph = OptimizedRenderizer.initial_render(Graph.build(), state)
    
    scene =
      scene
      |> assign(state: state, graph: graph)
      |> push_graph(graph)
    
    # Request input events
    request_input(scene, [:cursor_pos, :cursor_button])
    
    {:ok, scene}
  end
  
  @impl Scenic.Scene
  def handle_input({:cursor_pos, coords}, _context, scene) do
    state = scene.assigns.state
    
    # Update hover state
    new_state = Reducer.handle_cursor_pos(state, coords)
    
    if new_state != state do
      # Update only changed elements
      graph = OptimizedRenderizer.update_render(scene.assigns.graph, state, new_state)
      
      scene =
        scene
        |> assign(state: new_state, graph: graph)
        |> push_graph(graph)
    end
    
    {:noreply, scene}
  end
  
  def handle_input({:cursor_button, {:btn_left, 1, _, coords}}, _context, scene) do
    state = scene.assigns.state
    
    # Handle click
    case Reducer.handle_click(state, coords) do
      {:menu_item_clicked, item_id, new_state} ->
        # Send event to parent
        send_parent_event(scene, {:menu_item_clicked, item_id})
        
        graph = OptimizedRenderizer.update_render(scene.assigns.graph, state, new_state)
        
        scene =
          scene
          |> assign(state: new_state, graph: graph)
          |> push_graph(graph)
          
      {:noop, _state} ->
        scene
    end
    
    {:noreply, scene}
  end
  
  def handle_input(_input, _context, scene) do
    {:noreply, scene}
  end
  
  @impl GenServer
  def handle_cast({:set_active_menu, menu_id}, scene) do
    state = scene.assigns.state
    new_state = Api.set_active_menu(state, menu_id)
    
    graph = OptimizedRenderizer.update_render(scene.assigns.graph, state, new_state)
    
    scene =
      scene
      |> assign(state: new_state, graph: graph)
      |> push_graph(graph)
    
    {:noreply, scene}
  end
  
  def handle_cast({:close_all_menus}, scene) do
    state = scene.assigns.state
    new_state = Api.close_all_menus(state)
    
    graph = OptimizedRenderizer.update_render(scene.assigns.graph, state, new_state)
    
    scene =
      scene
      |> assign(state: new_state, graph: graph)
      |> push_graph(graph)
    
    {:noreply, scene}
  end
  
  def handle_cast(_msg, scene) do
    {:noreply, scene}
  end
end