defmodule ScenicWidgets.Menu.Model do
  @moduledoc "Typed data-only menu/popover contract."

  defmodule Item do
    @enforce_keys [:id, :label]
    defstruct [:id, :label, :icon, :shortcut, :tooltip, enabled?: true]
  end

  defmodule Toggle do
    @enforce_keys [:id, :label, :checked?]
    defstruct [:id, :label, :checked?, :tooltip, enabled?: true]
  end

  defmodule Radio do
    @enforce_keys [:id, :label, :group, :value, :selected?]
    defstruct [:id, :label, :group, :value, :selected?, :tooltip, enabled?: true]
  end

  defmodule Slider do
    @enforce_keys [:id, :label, :value, :min, :max]
    defstruct [:id, :label, :value, :min, :max, :tooltip, step: 1, enabled?: true]
  end

  defmodule Divider do
    @moduledoc "A non-interactive horizontal separator between groups of menu rows."
    @enforce_keys [:id]
    defstruct [:id, enabled?: false]
  end

  defmodule Select do
    @moduledoc "An inline dropdown selector with a finite set of choices."
    @enforce_keys [:id, :label, :value, :options]
    defstruct [
      :id,
      :label,
      :value,
      :options,
      :tooltip,
      expanded?: false,
      scroll_offset: 0,
      enabled?: true
    ]
  end

  defmodule Stepper do
    @moduledoc "A numeric menu control with reusable decrement and increment buttons."
    @enforce_keys [:id, :label, :value, :min, :max]
    defstruct [:id, :label, :value, :min, :max, :tooltip, step: 1, enabled?: true]
  end

  defmodule TreeNode do
    @moduledoc """
    One thing in a `Tree`: tickable, and possibly holding more of them.

    `children` being empty is what makes a node a leaf — there is no separate
    kind for it, because a directory with nothing in it and a file are the
    same thing as far as picking them goes.
    """
    @enforce_keys [:id, :label]
    defstruct [:id, :label, checked?: true, expanded?: false, children: []]
  end

  defmodule Tree do
    @moduledoc """
    A tree of things you can tick, inside a menu row.

    The same shape as `Select` — a row that expands in place rather than
    flying out sideways — but with more than one level and a tick on every
    node instead of one value out of a list. Anything a person needs to
    pick a SET out of, where the set has structure, fits here: which
    directories a search may look in, which buffers to act on, which of a
    project's targets to build.

    `max_visible` caps how many rows it takes up when open; past that it
    scrolls, exactly as an over-long `Select` does. A menu row that could
    grow to a project's worth of directories would otherwise be a menu with
    no bottom to it.
    """
    @enforce_keys [:id, :label, :nodes]
    defstruct [
      :id,
      :label,
      :nodes,
      :tooltip,
      expanded?: false,
      scroll_offset: 0,
      max_visible: 8,
      enabled?: true
    ]
  end

  defmodule Submenu do
    @enforce_keys [:id, :label, :rows]
    defstruct [:id, :label, :rows, :tooltip, enabled?: true]
  end

  defmodule Section do
    @enforce_keys [:id, :label]
    defstruct [:id, :label, enabled?: false]
  end

  @enforce_keys [:id, :rows]
  defstruct [:id, :rows, autohide?: true]

  def validate(%__MODULE__{id: id, rows: rows} = model) when is_atom(id) and is_list(rows) do
    with :ok <- unique_ids(rows), :ok <- valid_rows(rows), do: {:ok, model}
  end

  def validate(_), do: {:error, :invalid_menu}

  def event(%__MODULE__{id: menu_id}, %{id: item_id}, value \\ :activate),
    do: {:menu_action, menu_id, item_id, value}

  defp unique_ids(rows) do
    ids = Enum.flat_map(rows, &row_ids/1)
    if length(ids) == length(Enum.uniq(ids)), do: :ok, else: {:error, :duplicate_id}
  end

  defp row_ids(%Submenu{id: id, rows: rows}), do: [id | Enum.flat_map(rows, &row_ids/1)]
  defp row_ids(%{id: id}), do: [id]
  defp row_ids(_), do: []

  defp valid_rows(rows),
    do: if(Enum.all?(rows, &valid_row?/1), do: :ok, else: {:error, :invalid_row})

  defp valid_row?(%Submenu{rows: rows}), do: valid_rows(rows) == :ok

  defp valid_row?(%Slider{min: min, max: max, value: value, step: step}),
    do: is_number(value) and is_number(step) and step > 0 and value >= min and value <= max

  defp valid_row?(%module{})
       when module in [Item, Toggle, Radio, Section, Divider, Select, Stepper],
       do: true

  defp valid_row?(row) when row in [:divider, :space], do: true
  defp valid_row?(_), do: false

  # ── Working with a Tree ─────────────────────────────────────────────────
  #
  # Every part of a menu that deals with a tree — how tall the row is, what to
  # draw, what was clicked — needs the same thing: the nodes that are actually
  # showing, in order, each with how deep it is. So it is computed in one
  # place and handed out.

  @doc """
  How far one level of a tree is indented, in pixels.

  Defined ONCE and read by both the renderer and the reducer: it is what
  decides where a triangle is drawn AND what counts as a click on it, and the
  two disagreeing means a triangle you cannot hit.
  """
  def tree_indent, do: 12

  @doc "The nodes on screen, top to bottom, as `{node, depth}`."
  def visible_tree_nodes(%Tree{nodes: nodes}), do: visible_tree_nodes(nodes, 0)

  def visible_tree_nodes(nodes, depth) when is_list(nodes) do
    Enum.flat_map(nodes, fn %TreeNode{} = node ->
      if node.expanded? and node.children != [] do
        [{node, depth} | visible_tree_nodes(node.children, depth + 1)]
      else
        [{node, depth}]
      end
    end)
  end

  @doc "How many rows the tree shows, before `max_visible` is applied."
  def tree_node_count(%Tree{} = tree), do: length(visible_tree_nodes(tree))

  @doc """
  Replace a node anywhere in the tree, by id.

  `fun` receives the node and returns the new one. Nodes it does not match
  come back untouched, so a caller never has to walk the tree itself.
  """
  def update_tree_node(%Tree{nodes: nodes} = tree, node_id, fun) when is_function(fun, 1),
    do: %{tree | nodes: update_nodes(nodes, node_id, fun)}

  defp update_nodes(nodes, node_id, fun) do
    Enum.map(nodes, fn
      %TreeNode{id: ^node_id} = node -> fun.(node)
      %TreeNode{} = node -> %{node | children: update_nodes(node.children, node_id, fun)}
    end)
  end

  @doc "Tick or untick a node. Ticking is the caller's business below that."
  def toggle_tree_node(%Tree{} = tree, node_id),
    do: update_tree_node(tree, node_id, &%{&1 | checked?: not &1.checked?})

  @doc "Open or shut a node, which only means anything if it has children."
  def toggle_tree_expanded(%Tree{} = tree, node_id),
    do: update_tree_node(tree, node_id, &%{&1 | expanded?: not &1.expanded?})

  @doc "Find a node by id, or nil."
  def find_tree_node(%Tree{} = tree, node_id) do
    Enum.find_value(visible_tree_nodes(tree), fn {node, _depth} ->
      if node.id == node_id, do: node
    end)
  end

  # ── Reading a row ───────────────────────────────────────────────────────
  #
  # A row's id, its label, how tall it is — what anything drawing menu rows
  # needs to know. These lived in IconMenu.State, reachable by one component
  # only, which is why a second thing wanting to draw a menu row had to
  # reimplement one instead.

  @doc """
  Extract the ID from a menu item tuple (supports all formats).
  """
  def get_item_id({id, _label}), do: id
  def get_item_id({id, _label, _opts_or_action}), do: id
  def get_item_id(%{id: id}), do: id

  @doc """
  Extract the label from a menu item tuple.
  """
  def get_item_label({_id, label}), do: label
  def get_item_label({_id, label, _opts_or_action}), do: label
  def get_item_label(%{label: label}), do: label

  def display_label(%ScenicWidgets.Menu.Model.Divider{}), do: ""
  def display_label(%ScenicWidgets.Menu.Model.Select{label: label}), do: label

  def display_label(%ScenicWidgets.Menu.Model.Slider{label: label, value: value}),
    do: "#{label}: #{value}"

  def display_label(%ScenicWidgets.Menu.Model.Submenu{label: label}), do: label <> "  ›"

  # How much of the tree is unticked, on the row you open it from — the whole
  # reason to look at it is usually to check whether anything is switched off.
  def display_label(%ScenicWidgets.Menu.Model.Tree{label: label} = tree) do
    case unchecked_count(tree.nodes) do
      0 -> label
      n -> "#{label}  (#{n} off)"
    end
  end

  def display_label(item), do: get_item_label(item)

  # An unticked branch counts ONCE, not once per thing inside it: a folder
  # with forty files in it is one decision, not forty-one.
  defp unchecked_count(nodes) do
    Enum.reduce(nodes, 0, fn node, acc ->
      if node.checked?, do: acc + unchecked_count(node.children), else: acc + 1
    end)
  end

  @doc "Returns a menu item's shortcut as a separate, right-aligned column."
  def item_shortcut(item), do: item_shortcut(item, true)
  def item_shortcut(%{shortcut: shortcut}, true) when is_binary(shortcut), do: shortcut
  def item_shortcut(_item, _show_shortcuts), do: nil

  @doc "Returns the row height for an item; interactive sliders receive extra vertical space."
  def item_height(%ScenicWidgets.Menu.Model.Slider{}, theme),
    do: Map.get(theme, :dropdown_slider_height, 52)

  def item_height(%ScenicWidgets.Menu.Model.Divider{}, theme),
    do: Map.get(theme, :dropdown_divider_height, 13)

  def item_height(%ScenicWidgets.Menu.Model.Select{expanded?: true, options: options}, theme),
    do: theme.dropdown_item_height * (min(length(options), 4) + 1)

  # A tree takes its header row plus however much of itself is showing, capped
  # — a row that could grow to a project's worth of directories would be a
  # menu with no bottom to it. Past the cap it scrolls, like a long Select.
  def item_height(%ScenicWidgets.Menu.Model.Tree{expanded?: true} = tree, theme) do
    showing = min(ScenicWidgets.Menu.Model.tree_node_count(tree), tree.max_visible)
    theme.dropdown_item_height * (showing + 1)
  end

  def item_height(_item, theme), do: theme.dropdown_item_height

  def get_item_opts({_id, _label}), do: %{}
  def get_item_opts({_id, _label, opts}) when is_map(opts), do: opts
  def get_item_opts({_id, _label, _action}), do: %{}

  def get_item_opts(%ScenicWidgets.Menu.Model.Toggle{checked?: checked, enabled?: enabled}),
    do: %{type: :toggle, checked: checked, enabled: enabled}

  def get_item_opts(%ScenicWidgets.Menu.Model.Radio{selected?: selected, enabled?: enabled}),
    do: %{type: :radio, checked: selected, enabled: enabled}

  def get_item_opts(%ScenicWidgets.Menu.Model.Slider{enabled?: enabled}),
    do: %{type: :slider, enabled: enabled}

  def get_item_opts(%{enabled?: enabled}), do: %{enabled: enabled}

  @doc """
  Check if a menu item is a toggle type.
  """
  def is_toggle_item?(item) do
    opts = get_item_opts(item)
    Map.get(opts, :type) in [:toggle, :radio]
  end

  @doc """
  Check if a toggle item is checked.
  """
  def is_item_checked?(item) do
    opts = get_item_opts(item)
    Map.get(opts, :checked, false)
  end

  @doc "Whether a row can be interacted with at all."
  def item_enabled?(item), do: Map.get(get_item_opts(item), :enabled, true)
end
