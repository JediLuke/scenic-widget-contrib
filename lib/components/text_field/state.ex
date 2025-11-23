defmodule ScenicWidgets.TextField.State do
  @moduledoc """
  State management for the TextField component.

  Supports both single-line and multi-line text editing with configurable
  wrapping, scrolling, line numbers, and interaction modes.
  """

  defstruct [
    # Core
    :frame,                    # Widgex.Frame for positioning/sizing
    :lines,                    # List of strings: ["line 1", "line 2", ...]
    :cursor,                   # {line, col} tuple (1-indexed)
    :id,                       # Component ID (for events)

    # Display
    :focused,                  # Boolean, whether component has focus
    :cursor_visible,           # Boolean, for blink animation
    :cursor_timer,             # Erlang timer reference

    # Configuration
    :mode,                     # :single_line | :multi_line
    :input_mode,               # :direct | :external
    :show_line_numbers,        # Boolean
    :line_number_width,        # Pixels (default 40)
    :font,                     # %{name: atom, size: int, metrics: FontMetrics}
    :colors,                   # %{text:, background:, cursor:, line_numbers:, border:, focused_border:}

    # Interaction
    :editable,                 # Boolean (allow editing)
    :selectable,               # Boolean (allow text selection)

    # Text Wrapping & Scrolling (Phase 5)
    :wrap_mode,                # :none | :word | :char
    :scroll_mode,              # :none | :vertical | :horizontal | :both
    :vertical_scroll_offset,   # Vertical scroll in pixels
    :horizontal_scroll_offset, # Horizontal scroll in pixels
    :height_mode,              # :auto | {:fixed_lines, n} | {:fixed_pixels, n}
    :max_visible_lines,        # Calculated from frame height and height_mode

    # Advanced (future)
    :selection,                # {start, end} for text selection
    :max_lines,                # Limit lines (nil = unlimited)
    :cursor_blink_rate,        # Milliseconds
    :show_scrollbars,          # Boolean
    :scrollbar_width           # Pixels
  ]

  @type t :: %__MODULE__{}

  @doc """
  Create new state from Frame or config map.

  ## Examples

      # Minimal - just a frame
      State.new(%{frame: frame})

      # With configuration
      State.new(%{
        frame: frame,
        initial_text: "Hello\\nWorld",
        mode: :multi_line,
        show_line_numbers: true
      })
  """
  def new(%{frame: %Widgex.Frame{} = frame} = data) do
    font = Map.get(data, :font) || default_font()

    %__MODULE__{
      frame: frame,
      lines: parse_initial_text(data),
      cursor: {1, 1},
      id: Map.get(data, :id),

      # Display
      focused: false,
      cursor_visible: true,
      cursor_timer: nil,

      # Configuration
      mode: Map.get(data, :mode, :multi_line),
      input_mode: Map.get(data, :input_mode, :direct),
      show_line_numbers: Map.get(data, :show_line_numbers, false),
      line_number_width: Map.get(data, :line_number_width, 40),
      font: font,
      colors: Map.get(data, :colors) || default_colors(),

      # Interaction
      editable: Map.get(data, :editable, true),
      selectable: Map.get(data, :selectable, true),

      # Text Wrapping & Scrolling (defaults for Phase 1)
      wrap_mode: Map.get(data, :wrap_mode, :word),  # DEMO: Enable word wrap by default
      scroll_mode: Map.get(data, :scroll_mode, :both),
      vertical_scroll_offset: 0,
      horizontal_scroll_offset: 0,
      height_mode: Map.get(data, :height_mode, :auto),
      max_visible_lines: calculate_max_lines(frame, font),

      # Advanced
      selection: nil,
      max_lines: Map.get(data, :max_lines),
      cursor_blink_rate: Map.get(data, :cursor_blink_rate, 500),
      show_scrollbars: Map.get(data, :show_scrollbars, true),
      scrollbar_width: Map.get(data, :scrollbar_width, 12)
    }
  end

  defp parse_initial_text(%{initial_text: text}) when is_bitstring(text) do
    String.split(text, "\n")
  end
  defp parse_initial_text(_) do
    # Default to empty
    [""]
  end

  defp default_font do
    %{name: :roboto_mono, size: 20, metrics: nil}
  end

  defp default_colors do
    %{
      text: :white,
      background: {30, 30, 30},
      cursor: :white,
      line_numbers: {100, 100, 100},
      border: {60, 60, 60},
      focused_border: {100, 150, 200}
    }
  end

  defp calculate_max_lines(frame, font) do
    line_height = font.size
    trunc(frame.size.height / line_height)
  end

  # ===== QUERY FUNCTIONS (PURE) =====

  @doc """
  Check if point is inside TextField bounds.
  Coordinates are in component-local space (Scenic transforms them).
  """
  def point_inside?(%__MODULE__{frame: frame}, {x, y}) do
    # When component is added with translate, Scenic transforms input coords to local space
    # So we check against (0,0) origin, not frame.pin
    x >= 0 and x <= frame.size.width and
    y >= 0 and y <= frame.size.height
  end

  @doc """
  Get full text as single string with newlines.
  """
  def get_text(%__MODULE__{lines: lines}) do
    Enum.join(lines, "\n")
  end

  @doc """
  Get cursor position as {line, col} tuple (1-indexed).
  """
  def get_cursor(%__MODULE__{cursor: cursor}), do: cursor

  @doc """
  Get line at index (1-indexed). Returns empty string if out of bounds.
  """
  def get_line(%__MODULE__{lines: lines}, line_num) do
    Enum.at(lines, line_num - 1, "")
  end

  @doc """
  Count total lines in the text.
  """
  def line_count(%__MODULE__{lines: lines}), do: length(lines)

  @doc """
  Get the X offset where text starts (accounting for line numbers).
  """
  def text_x_offset(%__MODULE__{show_line_numbers: false}), do: 10
  def text_x_offset(%__MODULE__{show_line_numbers: true, line_number_width: width}), do: width + 10
end
