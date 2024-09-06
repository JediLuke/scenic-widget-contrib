# defmodule ScenicWidgets.NeoMenuBar do
#   # use Widgex.NeoComponent
#   # use Scenic.Component
#   # use ScenicWidgets.ScenicEventsDefinitions
#   # require Logger
#   # alias Widgex.Structs.{Coordinates, Dimensions, Frame}

#   @impl Scenic.Component
#   def validate(
#         %{
#           frame: %Widgex.Frame{},
#           state: %{mode: :inactive, menu_map: _menu_map},
#           theme: _theme
#         } = args
#       ) do
#     {:ok, args}
#   end

#   @impl Scenic.Component
#   def init(scene, args, _opts) do
#     # TODO stuff like theme, frame etc all needs to be apart of the "higher level" struct for a component, abstracted away from the component state... probably Scenic can does this or at least should do it!
#     # init_theme = ScenicWidgets.Utils.Theme.get_theme(opts)

#     # TODO probably need to register the component somehow here...

#     # If the component is properly registered we cuold check if it has already been rendered/spun-up and if it has, instead of rendering/spinning-up again, we could just push an update to it, sort of like a render_or_update function

#     # init_opts = Keyword.merge(opts, unquote(macro_opts))
#     init_graph = render(args)

#     init_scene =
#       scene
#       |> assign(graph: init_graph)
#       # |> assign(args: args)
#       # |> assign(frame: args.frame)
#       # # TODO bring opts into state eventually...
#       # |> assign(opts: init_opts)
#       |> push_graph(init_graph)

#     # if unquote(opts)[:handle_cursor_events?] do
#     #   request_input(init_scene, [:cursor_pos, :cursor_button])
#     # end

#     # QuillEx.Lib.Utils.PubSub.subscribe(topic: :radix_state_change)

#     {:ok, init_scene}
#   end

#   def render(args) do
#     Scenic.Graph.build()
#     |> Scenic.Primitives.group(
#       fn graph ->
#         graph
#         |> render_main_menu_bar(args)

#         # |> render_sub_menu_dropdowns(state)

#         # |> Scenic.Primitives.rectangle(
#         #   {w, h},
#         #   fill: :red
#         # )

#         # |> Scenic.Primitives.text(
#         #   "NeoMenuBar",
#         #   font_size: 20,
#         #   fill: {1.0, 1.0, 1.0, 1.0},
#         #   position: {10, 10}
#         # )
#       end,
#       id: :neo_menu_bar
#     )
#   end

#   def render_main_menu_bar(graph, %{frame: frame, state: c_state,}) do
#     # # strip out all the top-level menu item labels & give them a number
#     # pre_processed_menu_map =
#     #   state.menu_map
#     #   |> Enum.map(fn
#     #     # {label, _fn} ->
#     #     #   label
#     #     {:sub_menu, label, _sub_menu} ->
#     #       label
#     #   end)
#     #   |> Enum.with_index(1)

#     graph
#     |> Scenic.Primitives.group(fn graph ->
#       graph
#       |> Scenic.Primitives.rect(frame.size.box, fill: c_state.theme.active)

#       # |> do_render_main_menu_bar(state, frame, theme, pre_processed_menu_map)
#     end)
#   end

#   # Scenic.Graph.build()
#   #   |> Scenic.Primitives.group(
#   #     fn graph ->
#   #       graph
#   #       |> render_main_menu_bar(args)
#   #       |> render_sub_menu_dropdowns(args, sub_menu_dropdowns)
#   #     end,
#   #     id: :menu_bar
#   #   )
# end
