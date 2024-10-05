defmodule ScenicWidgets.SpareParts.LukesMultiSelect do
  use Scenic.Component, has_children: false

  alias Scenic.Graph
  alias Scenic.Scene
  alias Scenic.Primitive.Style.Theme
  import Scenic.Primitives
  alias Scenic.Assets.Static

  require Logger

  @default_direction :down
  @default_font :roboto
  @default_font_size 20
  @border_width 2

  @checkbox_size 16

  # --------------------------------------------------------
  @impl Scenic.Component
  def validate({items, _initial_selected_ids} = data) when is_list(items) do
    Enum.reduce(items, {:ok, data}, fn
      _, {:error, _} = error -> error
      {text, _}, acc when is_bitstring(text) -> acc
      item, _ -> err_bad_item(item, data)
    end)
  end

  def validate(data) do
    {:error,
     """
     Invalid MultiSelect specification
     Received: #{inspect(data)}
     MultiSelect data must be a list of text/id pairs and initial selected ids.
     """}
  end

  # --------------------------------------------------------
  @doc false
  @impl Scenic.Scene
  def init(scene, {items, initial_selected_ids}, opts) do
    id = opts[:id]
    theme = (opts[:theme] || Theme.preset(:dark)) |> Theme.normalize()

    {:ok, {Static.Font, fm}} = Static.meta(@default_font)
    ascent = FontMetrics.ascent(@default_font_size, fm)
    descent = FontMetrics.descent(@default_font_size, fm)

    # Calculate width and height of the component
    fm_width =
      Enum.reduce(items, 0, fn {text, _}, w ->
        width = FontMetrics.width(text, @default_font_size, fm)
        max(w, width)
      end)

    width = opts[:width] || fm_width + ascent * 3
    height = @default_font_size + ascent

    # Calculate the total height of the items list
    item_count = Enum.count(items)
    total_height = item_count * height

    translate_menu = {0, height + 1}

    # Build the graph for the component
    graph =
      Graph.build(font: @default_font, font_size: @default_font_size, t: {0, 0})
      |> rect({width, total_height}, fill: theme.background, stroke: {@border_width, theme.border})

    final_graph =
      Enum.reduce(items, graph, fn {text, id}, g ->
        is_selected = id in initial_selected_ids

        g
        |> group(
          fn g ->
            # Checkbox primitive
            g
            |> rect({@checkbox_size, @checkbox_size},
              fill: if(is_selected, do: theme.active, else: theme.background),
              stroke: {@border_width, theme.border},
              id: {:checkbox, id},
              input: :cursor_button
            )
            # Label for the item
            |> text(text,
              fill: theme.text,
              translate: {@checkbox_size + 8, height / 2 + ascent / 2 + descent / 3},
              id: {:label, id}
            )
          end,
          translate: {0, height * Enum.find_index(items, fn {_, item_id} -> item_id == id end)}
        )
      end)

    scene =
      scene
      |> assign(graph: final_graph, selected_ids: initial_selected_ids, theme: theme, id: id)
      |> push_graph(final_graph)

    {:ok, scene}
  end

  # Handle checkbox click events
  @impl Scenic.Scene
  def handle_input({:cursor_button, {:btn_left, 1, _, _}}, {:checkbox, item_id}, scene) do
    %{selected_ids: selected_ids, graph: graph, theme: theme} = scene.assigns

    new_selected_ids =
      if item_id in selected_ids do
        List.delete(selected_ids, item_id)
      else
        [item_id | selected_ids]
      end

    # Update the graph to reflect the new selection state
    graph =
      graph
      |> Graph.modify(
        {:checkbox, item_id},
        &update_opts(&1,
          fill: if(item_id in new_selected_ids, do: theme.active, else: theme.background)
        )
      )

    send_parent_event(scene, {:value_changed, scene.assigns.id, new_selected_ids})

    scene =
      scene
      |> assign(selected_ids: new_selected_ids, graph: graph)
      |> push_graph(graph)

    {:noreply, scene}
  end

  def handle_input(_, _, scene), do: {:noreply, scene}

  # --------------------------------------------------------
  defp err_bad_item(item, data) do
    {:error,
     """
     Invalid MultiSelect specification
     Received: #{inspect(data)}
     Invalid Item: #{inspect(item)}
     """}
  end
end
