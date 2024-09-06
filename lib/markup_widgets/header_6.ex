defmodule ScenicWidgets.Markup.Header6 do
  alias Widgex.Frame

  @font_size 24
  @left_margin 24

  def draw(graph, %Frame{} = f, text) when is_binary(text) do
    center_point = Frame.center(f)

    graph
    |> Scenic.Primitives.group(
      fn graph ->
        graph
        # |> Widgex.Frame.draw_guidewires(f, color: :pink)
        |> Scenic.Primitives.text(text,
          font_size: @font_size,
          fill: :black,
          translate: {@left_margin, (f.size.height - @font_size) / 2 + @font_size},
          text_align: :left
        )
      end
      # translate: f.pin.point,
      # NOTE adding scissor here will also cause it to not scissor!! Does this somehow override ones above it??
      # scissor: f.size.box
    )
  end
end
