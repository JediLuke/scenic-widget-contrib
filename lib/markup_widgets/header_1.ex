defmodule ScenicWidgets.Markup.Header1 do
  @font_size 40

  def draw(graph, frame, text) do
    center_point = Widgex.Frame.center(frame)

    IO.inspect(center_point)

    graph
    |> Scenic.Primitives.group(
      fn graph ->
        graph
        # |> Widgex.Frame.draw_guidewires(frame)
        |> Scenic.Primitives.text(text,
          font_size: @font_size,
          translate: {center_point.x, (frame.size.height - @font_size) / 2 + @font_size},
          text_align: :center
        )
      end,
      translate: frame.pin.point,
      scissor: frame.size.box
    )
  end
end
