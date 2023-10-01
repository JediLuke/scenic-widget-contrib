defmodule ScenicWidgets.UbuntuBar do
  use Widgex.Component

  defstruct id: __MODULE__,
            widgex: nil,
            menu_map: nil,
            theme: nil,
            layout: {:column, :center}

  def new(%{theme: rdx_theme} = args) do
    %__MODULE__{
      widgex: %{
        id: __MODULE__
      },
      menu_map: [
        %{id: :g1, glyph: "!", bg: rdx_theme.bg2, fg: rdx_theme.fg},
        %{id: :g2, glyph: "$", bg: rdx_theme.bg2, fg: rdx_theme.fg},
        %{id: :g3, glyph: "&", bg: rdx_theme.bg2, fg: rdx_theme.fg},
        %{id: :g4, glyph: "%", bg: rdx_theme.bg2, fg: rdx_theme.fg}
      ],
      theme: rdx_theme
    }
  end

  def radix_diff(%__MODULE__{} = old_state, fresh_radix_state) do
    new_state = new(fresh_radix_state)

    if old_state == new_state do
      {false, old_state}
    else
      {true, new_state}
    end
  end

  def render(%Scenic.Graph{} = graph, %__MODULE__{} = state, %Frame{} = f) do
    graph
    |> fill_frame(f, fill: state.theme.bg2)
    |> render_glyphs(state, f)
  end

  def render_glyphs(graph, %__MODULE__{layout: {:column, :center}} = state, %Frame{} = f) do
    # we want to render each glyph as a square, in a central column
    box_size = f.size.width

    {final_graph, _final_offset} =
      Enum.reduce(state.menu_map, {graph, _init_offset = 0}, fn glyph, {graph, offset} ->
        new_graph = graph |> render_glyph(glyph, box_size, offset)

        {new_graph, offset + 1}
      end)

    final_graph
  end

  # the glyph ratio is, what % of the box do we want to take up with the glyph
  @glyph_ratio 0.72
  def render_glyph(graph, glyph, box_size, offset) do
    # TODO...
    {:ok, ibm_plex_mono_font_metrics} =
      TruetypeMetrics.load("./assets/fonts/IBMPlexMono-Regular.ttf")

    size = box_size * @glyph_ratio

    font = %{
      size: size,
      metrics: ibm_plex_mono_font_metrics
    }

    char_width = FontMetrics.width(glyph.glyph, font.size, font.metrics)
    excess_width = box_size - char_width

    graph
    |> Scenic.Primitives.group(
      fn graph ->
        graph
        # |> Scenic.Primitives.rect(icon_size, fill: {:image, args.icon}, translate: translate)
        |> Scenic.Primitives.rect({box_size, box_size},
          id: glyph.id,
          input: :cursor_button,
          fill: glyph.bg || :black
        )
        |> Scenic.Primitives.text(glyph.glyph,
          font_size: size,
          fill: glyph.fg || :white,
          translate: {excess_width / 2, size}
        )
      end,
      id: __MODULE__,
      translate: {0, offset * box_size}
    )
  end

  def handle_input(
        {:cursor_button,
         {:btn_left, @clicked, _empty_list?, {_local_x, local_y} = _local_coords}},
        component_id,
        scene
      ) do
    send_parent_event(scene, {:glyph_clicked_event, component_id})
    {:noreply, scene}
  end

  def handle_input({:cursor_button, _details} = input, _context, scene) do
    Logger.debug("ignoring input.... #{inspect(input)}")
    {:noreply, scene}
  end
end
