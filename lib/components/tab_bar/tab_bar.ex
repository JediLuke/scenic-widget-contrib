defmodule ScenicWidgets.TabBar do
  @moduledoc """
  A horizontal tab bar component with VS Code-style appearance.

  ## Features
  - Horizontal scrolling when tabs overflow
  - Close buttons on individual tabs
  - Selection indicator (colored bottom stripe)
  - Hover highlighting
  - Dynamic tab width based on label length

  ## Usage

      tabs = [
        %{id: :file1, label: "main.ex"},
        %{id: :file2, label: "README.md"},
        %{id: :file3, label: "mix.exs", closeable: false}
      ]

      graph
      |> ScenicWidgets.TabBar.add_to_graph(
        %{frame: frame, tabs: tabs},
        id: :my_tab_bar
      )

  ## Events

  TabBar sends these events to the parent scene:
  - `{:tab_selected, tab_id}` - When a tab is clicked/selected
  - `{:tab_closed, tab_id}` - When a tab's close button is clicked

  Handle in your scene:

      def handle_event({:tab_selected, tab_id}, _from, scene) do
        # Switch to the selected tab's content
        {:noreply, scene}
      end

      def handle_event({:tab_closed, tab_id}, _from, scene) do
        # Handle tab closure (e.g., close file, prompt to save)
        {:noreply, scene}
      end

  ## Theme Customization

  Pass a `:theme` map to override defaults:

      %{
        frame: frame,
        tabs: tabs,
        theme: %{
          selection_indicator_color: {255, 100, 0},  # Orange indicator
          height: 40
        }
      }
  """

  use Scenic.Component, has_children: false
  require Logger

  alias ScenicWidgets.TabBar.{State, Reducer, Renderer}
  alias Scenic.Graph

  # Sample tabs for Widget Workbench demo
  @demo_tabs [
    %{id: :tab1, label: "main.ex"},
    %{id: :tab2, label: "lib/components/tab_bar.ex"},
    %{id: :tab3, label: "README.md"},
    %{id: :tab4, label: "mix.exs", closeable: false},
    %{id: :tab5, label: "config/config.exs"},
    %{id: :tab6, label: "test/tab_bar_test.exs"},
    %{id: :tab7, label: "very_long_filename_that_should_truncate.ex"}
  ]

  @impl Scenic.Component
  def validate(%Widgex.Frame{} = frame) do
    # Widget Workbench passes bare frame - add demo tabs
    {:ok, %{frame: frame, tabs: @demo_tabs}}
  end

  def validate(%{frame: %Widgex.Frame{}} = data) do
    {:ok, data}
  end

  def validate(%{frame: %{pin: _, size: _}} = data) do
    {:ok, data}
  end

  def validate(_) do
    {:error, "TabBar requires :frame (Widgex.Frame) and optional :tabs list"}
  end

  @impl Scenic.Scene
  def init(scene, data, _opts) do
    state = State.new(data)
    graph = Renderer.initial_render(Graph.build(), state)

    scene =
      scene
      |> assign(state: state, graph: graph)
      |> push_graph(graph)

    # Request input for mouse interaction
    request_input(scene, [:cursor_pos, :cursor_button, :cursor_scroll])

    Logger.debug("TabBar initialized with #{length(state.tabs)} tabs")

    {:ok, scene}
  end

  @impl Scenic.Scene
  def handle_input(input, _context, scene) do
    state = scene.assigns.state

    case Reducer.process_input(state, input) do
      {:noop, ^state} ->
        # No change
        {:noreply, scene}

      {:noop, new_state} ->
        # Internal state changed (hover, scroll)
        update_scene(scene, state, new_state)

      {:tab_selected, tab_id, new_state} ->
        send_parent_event(scene, {:tab_selected, tab_id})
        update_scene(scene, state, new_state)

      {:tab_closed, tab_id, new_state} ->
        send_parent_event(scene, {:tab_closed, tab_id})
        update_scene(scene, state, new_state)
    end
  end

  @impl Scenic.Scene
  def handle_put({:add_tab, tab}, scene) do
    state = scene.assigns.state

    case Reducer.add_tab(state, tab) do
      {:tab_added, _tab_id, new_state} ->
        graph = Renderer.initial_render(Graph.build(), new_state)
        scene = scene
          |> assign(state: new_state, graph: graph)
          |> push_graph(graph)
        {:noreply, scene}
    end
  end

  def handle_put({:select_tab, tab_id}, scene) do
    state = scene.assigns.state

    case Reducer.select_tab(state, tab_id) do
      {:noop, ^state} ->
        {:noreply, scene}

      {:tab_selected, _tab_id, new_state} ->
        update_scene_tuple(scene, state, new_state)
    end
  end

  def handle_put({:close_tab, tab_id}, scene) do
    state = scene.assigns.state

    case Reducer.close_tab(state, tab_id) do
      {:noop, ^state} ->
        {:noreply, scene}

      {:tab_closed, _tab_id, new_state} ->
        update_scene_tuple(scene, state, new_state)
    end
  end

  def handle_put(_msg, scene) do
    {:noreply, scene}
  end

  # ===========================================================================
  # Private Helpers
  # ===========================================================================

  defp update_scene(scene, old_state, new_state) do
    graph = Renderer.update_render(scene.assigns.graph, old_state, new_state)
    scene = scene
      |> assign(state: new_state, graph: graph)
      |> push_graph(graph)
    {:noreply, scene}
  end

  defp update_scene_tuple(scene, old_state, new_state) do
    graph = Renderer.update_render(scene.assigns.graph, old_state, new_state)
    scene = scene
      |> assign(state: new_state, graph: graph)
      |> push_graph(graph)
    {:noreply, scene}
  end
end
