defmodule Widgex.Layer do
  # TODO behaviours
  # need to implement init (comes from Scenic.Component)
  # need to implement cast
  # need to implement render

  # # take in the radix_state and return a derived state which describes the layer
  # # this is necessary because we use this to determinne if the layer has changed & thus needs to be redrawn
  # @callback cast(map()) :: map()

  # # take in the layer_state and return the graph describing the layer
  # # TODO this now takes in a viewport & a dstruct
  # @callback render(map()) :: %Scenic.Graph{}

  # defmodule Flamelex.GUI.Layer.Behaviour do
  #   # TODO document all this lol

  #   # take in the radix_state and return a derived state which describes the layer
  #   # this is necessary because we use this to determinne if the layer has changed & thus needs to be redrawn
  #   @callback cast(map()) :: map()

  #   # take in the layer_state and return the graph describing the layer
  #   # TODO this now takes in a viewport & a dstruct
  #   @callback render(map()) :: %Scenic.Graph{}
  # end

  defmacro __using__(_opts) do
    quote do
      use Scenic.Component
      require Logger

      alias Widgex.Frame
      # import Flamelex.Fluxus.Utils, only: [do_task: 1]

      # Validate the input data, required by Scenic
      # def validate(%{frame: %Frame{}, state: _s, pubsub: pubsub_mod} = data)
      #     when is_atom(pubsub_mod) do
      def validate(%{frame: %Frame{}, state: _s} = data) do
        {:ok, data}
      end

      @radix_state_change :radix_state_change
      def init(
            %Scenic.Scene{} = scene,
            %{frame: %Frame{} = frame, state: state},
            # %{frame: %Frame{} = frame, state: state, pubsub: pubsub},
            opts
          ) do
        Logger.debug("#{__MODULE__} initializing...")

        {:ok, new_graph} = render(frame, state)

        new_scene =
          scene
          |> assign(frame: frame)
          |> assign(state: state)
          |> assign(graph: new_graph)
          |> push_graph(new_graph)

        # TODO alternative idea, fetch the pubsub module via config
        # pubsub.subscribe(topic: @radix_state_change)

        Flamelex.Lib.Utils.PubSub.subscribe(topic: @radix_state_change)

        # TODO have an optional extra_init callback for Widgex components?
        # request_input(new_scene, [:cursor_pos])

        {:ok, new_scene}
      end

      # Initialize the scene
      # def init(
      #       %Scenic.Scene{} = scene,
      #       {radix_state, %LayerCake{layerable: layer_mod} = layer},
      #       opts
      #     ) do
      #   Logger.debug("#{__MODULE__} initializing...")

      #   {:ok, new_graph} = layer_mod.render(radix_state.gui.viewport, layer.state)

      #   new_scene =
      #     scene
      #     |> assign(graph: new_graph)
      #     |> assign(layer: layer)
      #     |> push_graph(new_graph)

      #   Flamelex.Lib.Utils.PubSub.subscribe(topic: :radix_state_change)

      #   request_input(new_scene, [:cursor_pos])

      #   {:ok, new_scene}
      # end

      def handle_info(
            {@radix_state_change, new_radix_state},
            %{assigns: %{frame: f, state: layer_state}} = scene
          ) do
        case Wormhole.capture(fn -> cast_rdx_to_layer_state(new_radix_state) end,
               crush_report: true
             ) do
          {:ok, ^layer_state} ->
            # nop change to the layer state to be made (note the pinned match)
            # todo maybe push this down to the components?? Nah, they can listen to the state change event
            # one idea about pushing it down might be that if we redraw this layer, other sub-components might be trying to update (due to radix state change, and them being subscribed to that)
            # but at the same time we're re-drawing the layer & are going to kill those components due to that redraw
            {:noreply, scene}

          {:ok, new_layer_state} ->
            # only re-render the frame (and therefore, all sub-components) if a layer-level change occured e.g. the layout shifted
            # TODO should check if we even change here, maybe we can just pass down the action to components
            # if the graph is unchanged, dont try to update it here
            # TODO call render_layer here & apply scissoring etc
            {:ok, %Scenic.Graph{} = new_graph} = render(f, new_layer_state)

            new_scene =
              scene
              |> assign(state: new_layer_state)
              |> assign(graph: new_graph)
              |> push_graph(new_graph)

            {:noreply, new_scene}

          {:error, _reason} ->
            {:noreply, scene}
        end
      end

      # Handle Radix state changes
      # def handle_info(
      #       {:radix_state_change, new_radix_state},
      #       %{
      #         assigns: %{
      #           layer: %LayerCake{
      #             state: old_layer_state,
      #             layerable: layer_mod
      #           }
      #         }
      #       } = scene
      #     ) do
      #   IO.puts("RADIX STATE CHANGED")

      #   new_layer_state = layer_mod.cast(new_radix_state)

      #   if new_layer_state != old_layer_state do
      #     IO.puts("LAYER CHANGED!!!")
      #     viewport = new_radix_state.gui.viewport
      #     {:ok, %Scenic.Graph{} = new_graph} = layer_mod.render(viewport, new_layer_state)

      #     new_scene =
      #       scene
      #       |> assign(state: new_layer_state)
      #       |> assign(graph: new_graph)
      #       |> push_graph(new_graph)

      #     {:noreply, new_scene}
      #   else
      #     {:noreply, scene}
      #   end
      # end

      # Handle other cases of Radix state changes (ignoring them by default)
      def handle_info({@radix_state_change, _new_radix_state}, scene) do
        Logger.debug("#{__MODULE__} ignoring a RadixState change...")
        {:noreply, scene}
      end

      # defp render_group(state, %Frame{} = frame, opts) do
      #   Scenic.Graph.build()
      #   |> Scenic.Primitives.group(
      #     fn graph ->
      #       graph
      #       # REMINDER: render/3 has to be implemented by the Widgex.Layer implementing this behaviour
      #       |> render(state, frame)

      #       # |> render_scrollbars(state, frame, opts)
      #     end,
      #     # trim outside the frame & move the frame to it's location
      #     id: {:widgex_layer, state.widgex.id},
      #     scissor: frame.size.box,
      #     translate: frame.pin.point
      #   )
      # end
    end
  end
end
