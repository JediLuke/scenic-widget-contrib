defmodule ScenicWidgets.TextField do
  @moduledoc """
  A multi-line text field component with support for both direct and external input modes.

  ## Features (Phase 1)
  - Multi-line and single-line modes
  - Optional line numbers
  - Blinking cursor
  - Configurable fonts and colors
  - Transparent background support

  ## Usage

      # Minimal configuration
      graph
      |> TextField.add_to_graph(
        %{
          frame: Widgex.Frame.new(pin: {100, 100}, size: {400, 300}),
          initial_text: "Hello World!\\nType here..."
        },
        id: :my_text_field
      )

      # With line numbers
      graph
      |> TextField.add_to_graph(
        %{
          frame: frame,
          initial_text: "line 1\\nline 2\\nline 3",
          show_line_numbers: true,
          mode: :multi_line
        },
        id: :code_editor
      )

  ## Input Modes

  ### Direct Mode (default)
  TextField handles keyboard input directly (Phase 2).
  Good for: forms, simple text editors, Widget Workbench.

  ### External Mode
  Parent scene controls all input via `handle_put/2` (Phase 3).
  Good for: Flamelex, vim-mode editors, complex applications.

  ## Events (Phase 2+)

  - `{:text_changed, id, full_text}` - Text content changed
  - `{:focus_gained, id}` - TextField gained focus
  - `{:focus_lost, id}` - TextField lost focus
  - `{:enter_pressed, id, text}` - Enter pressed (single-line mode only)
  """

  use Scenic.Component, has_children: false
  require Logger

  alias ScenicWidgets.TextField.{State, Renderer, Reducer}
  alias Scenic.Graph

  # ===== VALIDATION =====

  @doc """
  Validate TextField initialization data.

  Accepts:
  - Widgex.Frame directly (Widget Workbench passes this)
  - Map with :frame key containing Widgex.Frame
  """
  def validate(%Widgex.Frame{} = frame) do
    # Widget Workbench passes frame directly - wrap it in a map
    {:ok, %{frame: frame}}
  end

  def validate(%{frame: %Widgex.Frame{}} = data) do
    {:ok, data}
  end

  def validate(data) do
    {:error, "TextField requires Widgex.Frame or map with :frame. Got: #{inspect(data)}"}
  end

  # ===== LIFECYCLE =====

  @doc """
  Initialize the TextField component.
  """
  def init(scene, data, _opts) do
    # Create initial state
    state = State.new(data)

    # Render initial graph
    graph = Renderer.initial_render(Graph.build(), state)

    # Start cursor blink timer (only if editable)
    {:ok, timer} = if state.editable do
      :timer.send_interval(state.cursor_blink_rate, :blink)
    else
      {:ok, nil}
    end

    # Update state with timer reference
    state = %{state | cursor_timer: timer}

    # Phase 2: Request input if in direct mode
    if state.input_mode == :direct do
      request_input(scene, [:cursor_button, :key])
    end

    scene =
      scene
      |> assign(state: state, graph: graph)
      |> push_graph(graph)

    {:ok, scene}
  end

  # ===== INPUT HANDLING (Phase 2) =====

  def handle_input(input, _context, scene) do
    state = scene.assigns.state

    case Reducer.process_input(state, input) do
      {:noop, ^state} ->
        {:noreply, scene}

      {:noop, new_state} ->
        update_scene(scene, state, new_state)

      {:event, event_data, new_state} ->
        send_parent_event(scene, event_data)
        update_scene(scene, state, new_state)
    end
  end

  # ===== EXTERNAL CONTROL (Phase 3) =====

  # def handle_put({:action, action_type, data}, scene) do
  #   state = scene.assigns.state
  #
  #   case Reducer.process_action(state, {action_type, data}) do
  #     {:noop, new_state} ->
  #       update_scene(scene, state, new_state)
  #
  #     {:event, event_data, new_state} ->
  #       send_parent_event(scene, event_data)
  #       update_scene(scene, state, new_state)
  #   end
  # end
  #
  # def handle_put(text, scene) when is_bitstring(text) do
  #   # Simple text replacement
  #   state = %{scene.assigns.state | lines: String.split(text, "\n")}
  #   send_parent_event(scene, {:text_changed, scene.assigns.state.id, text})
  #   update_scene(scene, scene.assigns.state, state)
  # end

  # ===== CURSOR BLINK TIMER =====

  @doc """
  Handle cursor blink timer message.
  """
  def handle_info(:blink, scene) do
    state = scene.assigns.state

    # Toggle cursor visibility
    new_state = %{state | cursor_visible: !state.cursor_visible}

    # Update only the cursor (efficient partial update)
    graph = Renderer.update_cursor_visibility(scene.assigns.graph, new_state)

    scene =
      scene
      |> assign(state: new_state, graph: graph)
      |> push_graph(graph)

    {:noreply, scene}
  end

  # ===== HELPER FUNCTIONS =====

  defp update_scene(scene, old_state, new_state) do
    graph = Renderer.update_render(scene.assigns.graph, old_state, new_state)

    scene =
      scene
      |> assign(state: new_state, graph: graph)
      |> push_graph(graph)

    {:noreply, scene}
  end
end
