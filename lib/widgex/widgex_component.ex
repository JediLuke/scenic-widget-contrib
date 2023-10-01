defmodule Widgex.Component do
  # %__MODULE__{
  #   widgex: %Widgex.Component.Widget{
  #     id: :plaintext,
  #     # frame: %Frame{},
  #     theme: QuillEx.GUI.Themes.midnight_shadow()
  #     # layout: %Widgex.Layout{},

  #   },
  #   text: text,
  #   scroll: {0, 0}
  #   # file_bar: %{
  #   #   show?: true,
  #   #   filename: nil
  #   # }
  # }

  defmodule Widget do
    defstruct id: nil,
              frame: nil,
              theme: nil

    # layout: nil
  end

  # defstruct viewport: nil,
  # pid: nil,
  # module: nil,
  # theme: nil,
  # id: nil,
  # parent: nil,
  # children: nil,
  # child_supervisor: nil,
  # assigns: %{},
  # supervisor: nil,
  # stop_pid: nil

  # defstruct id: nil,
  #           state: nil
  #           frame: nil,
  #           theme: nil,
  #           layout: nil

  # TODO make a behaviour, widgex components must implement:
  # draw/1 - returns a new component state from incoming params
  # render/3 - renders the component state into a scenic graph

  defmacro __using__(opts) do
    # quote location: :keep, bind_quoted: [opts: opts] do
    quote bind_quoted: [opts: opts] do
      use Scenic.Component
      use ScenicWidgets.ScenicEventsDefinitions
      require Logger
      alias Widgex.Structs.{Coordinates, Dimensions, Frame}

      # maybe we shouldn't do this lol but it's the default left margin for text
      @left_margin 5

      # all Scenic components must implement this function, but for us it's always the same
      @impl Scenic.Component
      # TODO maybe there's some cool macros trick I can do to pattern matchy on a specific module struct here...
      # def validate({%Widget{} = _w, state, %Frame{} = frame, %Theme{} = _t}) when is_struct(state) do
      def validate({state, %Frame{} = frame}) when is_struct(state) do
        {:ok, {state, frame}}
      end

      # all Scenic components must implement this function,
      # but for us it's always the same
      @impl Scenic.Component
      def init(scene, {state, %Frame{} = frame}, opts) when is_struct(state) do
        # TODO stuff like theme, frame etc all needs to be apart of the "higher level" struct for a component, abstracted away from the component state... probably Scenic can does this or at least should do it!
        # init_theme = ScenicWidgets.Utils.Theme.get_theme(opts)

        # TODO probably need to register the component somehow here...

        # If the component is properly registered we cuold check if it has already been rendered/spun-up and if it has, instead of rendering/spinning-up again, we could just push an update to it, sort of like a render_or_update function

        init_graph = render_group(state, frame, opts)

        init_scene =
          scene
          |> assign(graph: init_graph)
          |> assign(state: state)
          |> assign(frame: frame)
          # TODO bring opts into state eventually...
          |> assign(opts: opts)
          |> push_graph(init_graph)

        # if unquote(opts)[:handle_cursor_events?] do
        #   request_input(init_scene, [:cursor_pos, :cursor_button])
        # end

        QuillEx.Lib.Utils.PubSub.subscribe(topic: :radix_state_change)

        {:ok, init_scene}
      end

      def handle_info(
            {:radix_state_change, new_radix_state},
            scene
          ) do
        # Note that we can't just directly compare old and new states because it may be more complicated, e.g. root scene only wants to change if the number of components changes, not the details of one component, even though these small changes cause a direct comparison to fail
        {scene_changed?, new_state} = radix_diff(scene.assigns.state, new_radix_state)

        if not scene_changed? do
          # any child components will get updates by being themselves subscribed to radix state changes...
          {:noreply, scene}
        else
          # TODO here attempt to update the existing graph
          # gg = scene.assigns.graph
          # dbg()

          # IO.inspect(scene.assigns.graph)

          # {:widgex_component, QuillEx.GUI.Components.PlainTextScrollable}

          # it would be good here to just use Graph.modify, especially for scrolol events

          # TODO here Scenic ought to be able to handle us updating the graph
          new_graph = render_group(new_state, scene.assigns.frame, scene.assigns.opts)

          # new_graph =
          #   scene.assigns.graph
          #   |> Scenic.Graph.map({:widgex_component, __MODULE__}, fn component ->
          #     IO.puts("HIHIHIHI")
          #     # graph
          #     render_group(new_state, scene.assigns.frame, scene.assigns.opts)
          #   end)

          new_scene =
            scene
            |> assign(state: new_state)
            |> assign(graph: new_graph)
            |> push_graph(new_graph)

          {:noreply, new_scene}
        end
      end

      defp render_group(state, %Frame{} = frame, _opts) do
        Scenic.Graph.build(font: :ibm_plex_mono)
        |> Scenic.Primitives.group(
          fn graph ->
            # this function has to be implemented by the Widgex.Component being made
            graph |> render(state, frame)

            # TODO add here, is scrollable??? if so, add scrollbars
          end,
          # trim outside the frame & move the frame to it's location
          id: {:widgex_component, state.widgex.id},
          scissor: Dimensions.box(frame.size),
          translate: Coordinates.point(frame.pin)
        )
      end

      @doc """
      A simple helper function which fills the frame with a color.
      """
      @opacity 0.5
      def fill_frame(
            %Scenic.Graph{} = graph,
            %Frame{size: f_size},
            opts \\ []
          ) do
        graph |> Scenic.Primitives.rect(Dimensions.box(f_size), opts)
      end

      # def handle_input({:cursor_pos, {_x, _y} = coords}, _context, scene) do
      #   IO.puts("HOVER COORDS: #{inspect(coords)}")
      #   # NOTE: `menu_bar_max_height` is the full height, including any
      #   #       currently rendered sub-menus. As new sub-menus of different
      #   #       lengths get rendered, this max-height will change.
      #   #
      #   #       menu_bar_max_height = @height + num_sub_menu*@sub_menu_height
      #   # {_x, _y, _viewport_width, menu_bar_max_height} = Scenic.Graph.bounds(scene.assigns.graph)

      #   # if y > menu_bar_max_height do
      #   #   GenServer.cast(self(), {:cancel, scene.assigns.state.mode})
      #   #   {:noreply, scene}
      #   # else
      #   #   # TODO here check if we veered of sideways in a sub-menu
      #   #   {:noreply, scene}
      #   # end

      #   {:noreply, scene}
      # end

      # def handle_input({:cursor_button, {:btn_left, 0, [], click_coords}}, _context, scene) do
      #   bounds = Scenic.Graph.bounds(scene.assigns.graph)

      #   if click_coords |> ScenicWidgets.Utils.inside?(bounds) do
      #     cast_parent(scene, {:click, scene.assigns.state.unique_id})
      #   end

      #   {:noreply, scene}
      # end
    end
  end
end
