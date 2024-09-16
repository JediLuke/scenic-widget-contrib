defmodule ScenicWidgets.Markup.Header1 do
  @font_size 40

  def draw(graph, %{frame: %Widgex.Frame{} = f, text: text})
      when is_binary(text) do
    graph
    |> Scenic.Primitives.group(
      fn graph ->
        graph
        # |> Widgex.Frame.draw_guidewires(frame)
        |> Scenic.Primitives.text(text,
          font_size: @font_size,
          translate: {Widgex.Frame.center(f).x, (f.size.height - @font_size) / 2 + @font_size},
          text_align: :center
        )
      end,
      translate: f.pin.point
    )
  end
end
