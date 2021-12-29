defmodule QuillEx.GUI.Components.EditPane do
    use Scenic.Component
    require Logger
    alias QuillEx.GUI.Components.{TabSelector, TextPad}

    @tab_selector_height 40 #TODO remove, this should come from the font or something

    def validate(%{frame: %{width: _w, height: _h, pin: _p}} = data) do
        Logger.debug "#{__MODULE__} accepted params: #{inspect data}"
        {:ok, data}
    end

    def init(scene, args, opts) do
        Logger.debug "#{__MODULE__} initializing..."
        Process.register(self(), __MODULE__)

        QuillEx.Utils.PubSub.register(topic: :radix_state_change)

        init_scene = scene
        |> assign(frame: args.frame)
        |> assign(graph: Scenic.Graph.build())
        #NOTE: no push_graph...

        {:ok, init_scene}
    end

    # Single buffer
    def handle_info({:radix_state_change, %{buffers: [%{id: id, data: d}], active_buf: id}}, scene) do
        Logger.debug "drawing a single TextPad since we have only one buffer open!"

        new_graph = scene.assigns.graph
        |> Scenic.Graph.delete(:edit_pane)
        |> Scenic.Primitives.group(fn graph ->
                graph
                |> TextPad.add_to_graph(%{frame: %{
                      pin: {0, 0}, #NOTE: We don't need to move the pane around (referened from the outer frame of the EditPane) because there's no TabSelector being rendered (this is the single-buffer case)
                      size: {scene.assigns.frame.width, scene.assigns.frame.height}},
                   data: d},
                   id: :text_pad)
        end, translate: scene.assigns.frame.pin, id: :edit_pane)

        new_scene = scene
        |> assign(graph: new_graph)
        |> push_graph(new_graph)

        {:noreply, new_scene}
    end

    # Multiple buffers (so we render TabSelector, and move the TextPad down a bit)
    def handle_info({:radix_state_change, %{buffers: buf_list} = new_state}, scene) when length(buf_list) >= 2 do
        Logger.debug "drawing a TextPad which has been moved down a bit, to make room for a TabSelector"

        [full_active_buffer] = buf_list |> Enum.filter(& &1.id == new_state.active_buf)
        IO.inspect full_active_buffer.data, label: "REAL TEXT"

        Logger.warn "Not rendering real text..."
        # test_data = "Hello, this is Limelek!"

        new_graph = scene.assigns.graph
        |> Scenic.Graph.delete(:edit_pane)
        |> Scenic.Primitives.group(fn graph ->
                graph
                |> TabSelector.add_to_graph(%{radix_state: new_state, width: scene.assigns.frame.width, height: @tab_selector_height})
                |> TextPad.add_to_graph(%{frame: %{
                     pin: {0, @tab_selector_height}, #REMINDER: We need to move the TextPad down a bit, to make room for the TabSelector
                     size: {scene.assigns.frame.width, scene.assigns.frame.height-@tab_selector_height}},
                   data: full_active_buffer.data},
                   id: :text_pad)
        end, translate: scene.assigns.frame.pin, id: :edit_pane)

        new_scene = scene
        |> assign(graph: new_graph)
        |> push_graph(new_graph)

        {:noreply, new_scene}
    end

end