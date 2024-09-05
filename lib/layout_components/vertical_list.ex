defmodule ScenicWidgets.VerticalList do
  use Scenic.Component
  require Logger
  alias Widgex.Structs.Frame

  def validate(%{frame: _frame, items: _item_list} = data) do
    {:ok, data}
  end

  def init(scene, args, opts) do
    # Logger.debug "#{__MODULE__} initializing..."

    # TODO here we break the frame down into sub-frames and pass those
    # to the list of component/args, and just add those components with each frame

    init_graph = init_render(args)

    init_scene =
      scene
      # |> assign(id: id)
      |> assign(graph: init_graph)
      |> assign(frame: args.frame)
      # |> assign(theme: theme)
      |> assign(items: [])
      |> assign(scroll: {0, 0})
      |> assign(render_queue: args.items)
      |> push_graph(init_graph)

    GenServer.cast(self(), :render_next_component)

    # request_input(init_scene, [:cursor_pos, :cursor_button])
    request_input(init_scene, [:cursor_scroll])

    {:ok, init_scene}
  end

  def init_render(%{frame: f}) do
    Scenic.Graph.build()
    |> Scenic.Primitives.group(
      fn graph ->
        graph
        # |> ScenicWidgets.FrameBox.add_to_graph(%{frame: f, fill: :pink})
        # NOTE- make the container group, give it translation etc, just don't add any components yet
        |> Scenic.Primitives.group(
          fn graph ->
            graph
          end,
          # NOTE: We will scroll this pane around later on, and need to
          #      add new TidBits to it with Modify
          # Scenic required we register groups/components with a name
          id: :v_list_window,
          translate: {0, 0}
        )

        # draw a scissor rect around the entire list
        # |> Scenic.Primitives.rect(
        #   f.size.box,
        #   scissor: f.size.box
        # )
      end,
      # this scissor is _essential_ it's the only one that works lol
      scissor: f.size.box
    )

    # |> Scenic.Primitives.rect(
    #   f.size.box,
    #   scissor: f.size.box
    # )
  end

  def handle_input(
        {:cursor_scroll, {{_x_scroll, y_scroll} = delta_scroll, coords}},
        _context,
        scene
      ) do
    # TODO handle all this via a Reducer?? Or just keep it in the component??
    # Flamelex.Fluxus.action({Flamelex.Fluxus.Reducers.Memex, {:scroll, delta_scroll, __MODULE__}})

    new_cumulative_scroll = compute_scroll(scene.assigns.scroll, delta_scroll)

    new_graph =
      scene.assigns.graph
      |> Scenic.Graph.modify(
        :v_list_window,
        &Scenic.Primitives.update_opts(&1, translate: new_cumulative_scroll)
      )

    new_scene =
      scene
      |> assign(graph: new_graph)
      |> assign(scroll: new_cumulative_scroll)
      |> push_graph(new_graph)

    {:noreply, new_scene}
  end

  @fast_scroll_speed 20
  def compute_scroll({_x, _y} = current_cumulative_scroll, {_dx, dy}) do
    # TODO cap scroll - right now we just dont allow negative scrolling

    # speed up scrolling, and we never scroll in x direction (yet)
    fast_scroll = {0, @fast_scroll_speed * dy}

    new_cumulative_scroll =
      current_cumulative_scroll
      |> Scenic.Math.Vector2.add(fast_scroll)

    case new_cumulative_scroll do
      {x, y} when y > 0 ->
        # we want to be able to scroll "down" the list but
        # not "up" past the starting point, therefore
        # we only allow negative y values when scrolling
        {x, 0}

      {x, y} ->
        {x, y}
    end
  end

  def handle_cast(:render_next_component, %{assigns: %{render_queue: []}} = scene) do
    # Logger.debug "#{__MODULE__} ignoring a request to render a component, there's nothing to render"
    {:noreply, scene}
  end

  def handle_cast(
        :render_next_component,
        %{assigns: %{render_queue: [{module, args} = item | rest]}} = scene
      ) do
    Logger.debug("#{__MODULE__} attempting to render an additional component... #{inspect(item)}")

    # rendered_items = scene.assigns.items ++ [item]

    # note - need to calculate the item frame using the existing item list, not after we've added the new one!
    args = put_in(args, [:frame], calc_item_frame(scene.assigns.frame, scene.assigns.items))

    # |> Scenic.Graph.add_to(:river_pane, fn graph ->
    #   graph
    #   # |> ScenicWidgets.FrameBox.add_to_graph(%{frame: Frame.new(%{pin: {400, 400}, size: {400, 400}}), fill: :blue})
    #   # |> ScenicWidgets.FrameBox.add_to_graph(%{frame: calc_hypercard_frame(scene), fill: :blue})
    #   |> Memelex.GUI.Components.HyperCard.add_to_graph(%{
    #     # id: tidbit.uuid,
    #     frame: calc_hypercard_frame(scene),
    #     # frame: Frame.new(%{pin: {400, 400}, size: {400, 400}}),
    #     state: tidbit
    #     # state: %{uuid: "123"}
    #   })

    #   # TODO pass id in the opts
    # end)

    new_graph =
      scene.assigns.graph
      |> Scenic.Graph.add_to(:v_list_window, fn graph ->
        graph |> module.add_to_graph(args)
      end)

    # |> module.add_to_graph(args)
    # |> Scenic.Graph.add_to(:river_pane, fn graph ->
    #   graph
    #   # |> ScenicWidgets.FrameBox.add_to_graph(%{frame: Frame.new(%{pin: {400, 400}, size: {400, 400}}), fill: :blue})
    #   # |> ScenicWidgets.FrameBox.add_to_graph(%{frame: calc_hypercard_frame(scene), fill: :blue})
    #   |> Memelex.GUI.Components.HyperCard.add_to_graph(%{
    #     # id: tidbit.uuid,
    #     frame: calc_hypercard_frame(scene),
    #     # frame: Frame.new(%{pin: {400, 400}, size: {400, 400}}),
    #     state: tidbit
    #     # state: %{uuid: "123"}
    #   })

    #   # TODO pass id in the opts
    # end)

    new_scene =
      scene
      |> assign(graph: new_graph)
      |> assign(items: scene.assigns.items ++ [item])
      |> assign(render_queue: rest)
      |> push_graph(new_graph)

    GenServer.cast(self(), :render_next_component)

    {:noreply, new_scene}
  end

  # def bounds(%{frame: %{pin: {top_left_x, top_left_y}, size: {width, height}}}, _opts) do
  #   # NOTE: Because we use this bounds/2 function to calculate whether or
  #   # not the mouse is hovering over any particular button, we can't
  #   # translate entire groups of sub-menus around. We ned to explicitely
  #   # draw buttons in their correct order, and not translate them around,
  #   # because bounds/2 doesn't seem to work correctly with translated elements
  #   # TODO talk to Boyd and see if I'm wrong about this, or maybe we can improve Scenic to work with it
  #   left = top_left_x
  #   right = top_left_x + width
  #   top = top_left_y
  #   bottom = top_left_y + height
  #   {left, top, right, bottom}
  # end

  # def calc_item_frame(%{
  def calc_item_frame(%Frame{size: %{width: w}}, state) do
    # assigns: %{
    #   frame: %Frame{pin: %{x: x, y: y}, size: %{width: w}},
    #   state: state
    # }
    # }) do
    # TODO really calculate height
    item_height = 100
    items_offset = item_height * Enum.count(state)
    # extra_vertial_space = @spacing_buffer * Enum.count(open_tidbits_list)

    Frame.new(
      # pin: {x + @spacing_buffer, y + @spacing_buffer + open_tidbits_offset + extra_vertial_space},
      #  size: {w-(2*@spacing_buffer), {:flex_grow, %{min_height: 500}}})
      # TODO
      # size: {w - 2 * @spacing_buffer, 500}
      %{
        pin: {0, items_offset},
        size: {w, item_height}
      }
    )
  end
end