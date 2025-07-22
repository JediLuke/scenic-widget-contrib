# defmodule WidgetWorkbench.Widget.Struct do
#   defstruct [:id, :name, :type, :properties]
# end

# %Editor.WidgetConstruction{
#   id: "main_editor",
#   type: :container,
#   files: ["editor.ex", "editor_render.ex", "editor_state.ex"],
#   sub_widgets: [
#     %Editor.WidgetConstruction{
#       id: "text_box_1",
#       type: :text_box,
#       files: ["editor_render.ex"],
#       attributes: %{position: {10, 20}, size: {200, 50}},
#       construction_state: :in_progress
#     },
#     %Editor.WidgetConstruction{
#       id: "submit_button",
#       type: :button,
#       files: ["editor_user_input_handler.ex", "editor_render.ex"],
#       attributes: %{position: {10, 80}, size: {100, 30}, content: "Submit"},
#       construction_state: :complete
#     }
#   ],
#   attributes: %{position: {0, 0}, size: {500, 500}},
#   construction_state: :in_progress
# }
