defmodule Widgex.Structs.LayerCake do
  @moduledoc """
  Represents a Layer within the Widgex component management framework.

  A LayerCake can be thought of as a level within a graphical interface, defining the visual and functional characteristics at that level.

  ## Fields

  - `visible?`: Indicates whether the layer is visible or not. Defaults to `false`.
  <!-- - `frame`: The frame associated with the layer, representing its size and position. -->
  - `state`: The internal state of the component within the layer.
  - `layerable`: Module which implements the layer behavior, and defines the state strucft for this layer
  - `layout`: The layout associated with the layer.
  """

  @type t :: %__MODULE__{
          id: atom(),
          # visible?: boolean(),
          # TODO this needs to be a frame_stack (??)
          frame: Widgex.Frame.t() | nil,
          state: struct() | nil,
          layerable: struct() | nil
          # layout: Widgex.Structs.Layout.t() | nil
        }

  defstruct id: nil,
            # visible?: false,
            frame: nil,
            state: nil,
            # layerable is the module which represents the layer struct and implements the layer behaviour, we could do with a better name or maybe combine it with state somehow?
            layerable: nil,
            layout: nil,
            # components is our list of %Widgex.Component{} which will get paired with a frame
            components: []

  def new(args) do
    id = args["id"] || raise "must provide an id"
    # idea make the default frame the viewport? It is a layer after all...
    # frame = args["frame"] || raise "must provide a frame"
    state = args["state"] || raise "must provide a state"
    layerable = args["layerable"] || raise "must provide a layerable"

    %__MODULE__{
      id: id,
      # frame: frame,
      state: state,
      # layout: %Widgex.Structs.GridLayout{}
      layerable: layerable
    }
  end

  # # Define a function to validate a layer
  # def validate(%{layerable: layer} = data) do
  #   if Code.ensure_loaded?(layer) do
  #     {:ok, data}
  #   else
  #     {:error, "Invalid layer module"}
  #   end
  # end

  # # Initialize a layer with provided arguments
  # def init(scene, %{layer_mod: layer, radix_state: radix_state} = args, opts) do
  #   init_state = layer.calc_state(radix_state)
  #   {:ok, init_graph} = layer.render(init_state, radix_state)

  #   init_scene =
  #     scene
  #     |> assign(layer: %__MODULE__{frame: args.frame, layout: args.layout, layer_mod: layer})
  #     |> assign(graph: init_graph)
  #     |> assign(state: init_state)
  #     |> push_graph(init_graph)

  #   {:ok, init_scene}
  # end

  # # Handling layer updates on state changes
  # def handle_info(
  #       {:radix_state_change, new_radix_state},
  #       %{assigns: %{layer: %__MODULE__{layer_mod: layer, state: old_layer_state}}} = scene
  #     ) do
  #   new_layer_state = layer.calc_state(new_radix_state)

  #   if new_layer_state != old_layer_state do
  #     case layer.render(new_layer_state, new_radix_state) do
  #       :ignore ->
  #         {:noreply, scene}

  #       {:ok, %Scenic.Graph{} = new_graph} ->
  #         new_scene =
  #           scene
  #           |> assign(state: new_layer_state)
  #           |> assign(graph: new_graph)
  #           |> push_graph(new_graph)

  #         {:noreply, new_scene}
  #     end
  #   else
  #     {:noreply, scene}
  #   end
  # end

  # Additional handle_info cases can be defined here
end

# defmodule Widgex.Structs.Layer do
#   @moduledoc """
#   Represents a Layer within the Widgex component management framework.

#   A Layer can be thought of as a level within a graphical interface, defining the visual and functional characteristics at that level.

#   ## Fields

#   - `visible?`: Indicates whether the layer is visible or not. Defaults to `false`.
#   - `frame`: The frame associated with the layer, representing its size and position.
#   - `state`: The internal state of the component within the layer.
#   """

#   @type t :: %__MODULE__{
#           visible?: boolean(),
#           frame: Widgex.Frame.t() | nil,
#           state: map() | nil
#         }

#   defstruct visible?: false,
#             frame: nil,
#             state: nil
# end

# # defmodule Flamelex.GUI.Component.Layer do
# #   use Scenic.Component
# #   require Logger

# #   @layers [
# #     Flamelex.GUI.Layers.LayerZero,
# #     Flamelex.GUI.Layers.LayerOne,
# #     Flamelex.GUI.Layers.LayerTwo,
# #     Flamelex.GUI.Layers.LayerThree
# #   ]

# #   # #TODO accept a function, which is the render function - takes in a radix_state, re-computes entire layer, this is how we know if layers needs to be updated!!
# #   # def validate(%{graph: %Scenic.Graph{} = _g, render_fn: render_fn} = data) when is_function(render_fn) do
# #   #    {:ok, data}
# #   # end

# #   def validate(%{layer_module: layer, radix_state: radix_state} = data) when layer in @layers do
# #     {:ok, data}
# #   end

# #   # TODO handle the state & calc_state_fn not being mandatory args...

# #   def init(scene, %{layer_module: layer, radix_state: radix_state} = args, opts) do
# #     # Logger.debug "Initializing layer #{opts[:id]}..."

# #     init_state = layer.calc_state(radix_state)
# #     {:ok, init_graph} = layer.render(init_state, radix_state)

# #     init_scene =
# #       scene
# #       # |> assign(id: opts[:id] || raise "invalid ID")
# #       |> assign(layer: layer)
# #       |> assign(graph: init_graph)
# #       |> assign(state: init_state)
# #       |> push_graph(init_graph)

# #     Flamelex.Lib.Utils.PubSub.subscribe(topic: :radix_state_change)

# #     {:ok, init_scene}
# #   end

# #   # def init(scene, args, opts) do
# #   #    init_scene = scene
# #   #    |> assign(id: opts[:id] || raise "invalid ID")
# #   #    |> assign(render_fn: args.render_fn)
# #   #    |> assign(calc_state_fn: args[:calc_state_fn] || nil)
# #   #    |> assign(graph: args.graph)
# #   #    |> assign(state: args[:state] || nil)
# #   #    |> push_graph(args.graph)

# #   #    Flamelex.Lib.Utils.PubSub.subscribe(topic: :radix_state_change)

# #   #    {:ok, init_scene}
# #   # end

# #   # NOTE that this is better because it uses the "layer state" to figure out if it needs to change. Layer state doesn't need to change *all* the time e.g. if we input a single character... that can be handled by the Editor component
# #   def handle_info(
# #         {:radix_state_change, new_radix_state},
# #         # %{assigns: %{state: old_layer_state, layer: layer}} = scene
# #         # %{assigns: %{state: old_layer_state, layer: layer}} = scene
# #         %{assigns: %{layer: %LayerCake{
# #           frame:
# #           layout:
# #           layer_mod: # module which implements the layer behaviour
# #         }}} = scene
# #       ) do
# #     # NOTE here is where layer updates happen
# #     new_layer_state = layer.calc_state(new_radix_state)

# #     if new_layer_state != old_layer_state do
# #       case layer.render(new_layer_state, new_radix_state) do
# #         :ignore ->
# #           {:noreply, scene}

# #         {:ok, %Scenic.Graph{} = new_graph} ->
# #           new_scene =
# #             scene
# #             |> assign(state: new_layer_state)
# #             |> assign(graph: new_graph)
# #             |> push_graph(new_graph)

# #           {:noreply, new_scene}
# #       end
# #     else
# #       {:noreply, scene}
# #     end
# #   end

# #   # def handle_info({:radix_state_change, %{root: %{layers: layer_list}}}, scene) do
# #   # def handle_info({:radix_state_change, new_radix_state}, scene) do

# #   #    # #ONE IDEA - instead of triggering by changings in the layer list, re-compute the graph for this layer and change if it's it's changed...
# #   #    recomputed_layer_graph = scene.assigns.render_fn.(new_radix_state)

# #   #    # this_layer = scene.assigns.id #REMINDER: this will be an atom, like `:one`
# #   #    # [{^this_layer, this_layer_graph}] =
# #   #    #    layer_list |> Enum.filter(fn {layer, _graph} -> layer == scene.assigns.id end)

# #   #    if scene.assigns.graph != recomputed_layer_graph do
# #   #       IO.puts "!!!LAYER CHANGE!!!"
# #   #       Logger.debug "#{__MODULE__} Layer: #{inspect scene.assigns.id} changed, re-drawing the RootScene..."

# #   #       new_scene = scene
# #   #       |> assign(graph: recomputed_layer_graph)
# #   #       |> push_graph(recomputed_layer_graph)

# #   #       {:noreply, new_scene}
# #   #    else
# #   #       #Logger.debug "Layer #{inspect scene.assigns.id}, ignoring.."
# #   #       {:noreply, scene}
# #   #    end
# #   # end

# #   def handle_info({:radix_state_change, _new_radix_state}, scene) do
# #     # Logger.debug "#{__MODULE__} ignoring a RadixState change..."
# #     {:noreply, scene}
# #   end
# # end
