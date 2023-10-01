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

  defmacro __using__(macro_opts) do
    quote location: :keep, bind_quoted: [macro_opts: macro_opts] do
      # quote bind_quoted: [macro_opts: macro_opts] do
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

        init_opts = Keyword.merge(opts, unquote(macro_opts))
        init_graph = render_group(state, frame, init_opts)

        init_scene =
          scene
          |> assign(graph: init_graph)
          |> assign(state: state)
          |> assign(frame: frame)
          # TODO bring opts into state eventually...
          |> assign(opts: init_opts)
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
          new_graph = render_group(new_state, scene.assigns.frame, scene.assigns.opts)

          # TODO this is an idea about looping through components in radix state & updating them using Graph.modify
          # it would be good here to just use Graph.modify, especially for scrolol events

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

      defp render_group(state, %Frame{} = frame, opts) do
        Scenic.Graph.build(font: :ibm_plex_mono)
        |> Scenic.Primitives.group(
          fn graph ->
            graph
            # REMINDER: render/3 has to be implemented by the Widgex.Component implementing this behaviour
            |> render(state, frame)
            |> render_scrollbars(state, frame, opts)
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
      def fill_frame(
            %Scenic.Graph{} = graph,
            %Frame{size: f_size},
            opts \\ []
          ) do
        graph |> Scenic.Primitives.rect(Dimensions.box(f_size), opts)
      end

      defp render_scrollbars(graph, state, frame, opts) do
        case Keyword.get(opts, :scrollable) do
          :all_axis ->
            graph
            |> render_scrollbar_x(state, frame, opts)
            |> render_scrollbar_y(state, frame, opts)

          _otherwise ->
            graph
        end
      end

      @scrollbar_size 20
      @scrollbar_bg_opacity @fifteen_percent_opaque
      @scrollbar_fg_opacity @thirty_percent_opaque
      defp render_scrollbar_x(graph, state, frame, opts) do
        {left, top, right, bottom} = Scenic.Graph.bounds(graph)
        unscissored_width = right - left

        if unscissored_width > frame.size.width do
          # if we are going to render a vertical scrollbar we need to make room for it
          unscissored_height = bottom - top

          full_scrollbar_width =
            if unscissored_height > frame.size.height do
              frame.size.width - @scrollbar_size
            else
              frame.size.width
            end

          {scroll_x, _scroll_y} = state.scroll

          content_box_scroll_offset =
            frame.size.width * (-1 * scroll_x / (unscissored_width - frame.size.width))

          content_box_width = frame.size.width * (frame.size.width / unscissored_width)

          {r, g, b} = state.widgex.theme.accent2

          graph
          |> Scenic.Primitives.group(
            fn graph ->
              graph
              |> Scenic.Primitives.rect({full_scrollbar_width, @scrollbar_size},
                fill: {r, g, b, @scrollbar_bg_opacity}
              )
              |> Scenic.Primitives.rect({content_box_width, @scrollbar_size},
                id: {:widgex_component, state.widgex.id, :scrollbar_x_content_box},
                fill: {r, g, b, @scrollbar_fg_opacity},
                translate: {content_box_scroll_offset, 0},
                input: [:cursor_pos]
              )
            end,
            id: {:widgex_component, state.widgex.id, :scrollbar_x},
            translate: {0, frame.size.height - @scrollbar_size}
          )
        else
          # no need to render an x scrollbar...
          graph
        end
      end

      defp render_scrollbar_y(graph, state, frame, opts) do
        {_left, top, _right, bottom} = Scenic.Graph.bounds(graph)
        unscissored_height = bottom - top

        if unscissored_height > frame.size.height do
          # to calculate the size of the "content box" on the scrollbar,
          # we need to know what % of the underlying content is visible
          # inside the current Frame - this is x% of the content, so
          # we need to make the content box x% of the scrollbar size
          {_scroll_x, scroll_y} = state.scroll

          content_box_scroll_offset =
            frame.size.height * (-1 * scroll_y / (unscissored_height - frame.size.height))

          content_box_height = frame.size.height * (frame.size.height / unscissored_height)

          {r, g, b} = state.widgex.theme.accent2

          graph
          |> Scenic.Primitives.group(
            fn graph ->
              graph
              |> Scenic.Primitives.rect({@scrollbar_size, frame.size.height},
                fill: {r, g, b, @scrollbar_bg_opacity}
              )
              |> Scenic.Primitives.rect({@scrollbar_size, content_box_height},
                id: {:widgex_component, state.widgex.id, :scrollbar_y_content_box},
                fill: {r, g, b, @scrollbar_fg_opacity},
                translate: {0, content_box_scroll_offset},
                input: [:cursor_pos]
              )
            end,
            id: {:widgex_component, state.widgex.id, :scrollbar_y},
            translate: {frame.size.width - @scrollbar_size, 0}
          )
        else
          # no need to render a y scrollbar...
          graph
        end
      end

      def handle_input(
            {:cursor_pos, {_x, _y} = coords},
            scroll_box = {:widgex_component, __MODULE__, content_box},
            scene
          )
          when content_box in [:scrollbar_x_content_box, :scrollbar_y_content_box] do
        # [
        #   %Scenic.Primitive{data: box_size}
        # ] = Scenic.Graph.get(scene.assigns.graph, scroll_box)

        # IO.inspect(primitive)

        # Graph.modify(graph, :rect, fn(p) ->
        #   update_opts(p, rotate: 0.5)
        # end)

        {r, g, b} = scene.assigns.state.widgex.theme.accent2

        new_graph =
          scene.assigns.graph
          |> Scenic.Graph.modify(
            scroll_box,
            &Scenic.Primitives.update_opts(&1, fill: {r, g, b, @sixty_percent_opaque})
          )

        new_scene =
          scene
          # |> assign(state: new_state)
          |> assign(graph: new_graph)
          |> push_graph(new_graph)

        {:noreply, new_scene}
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
