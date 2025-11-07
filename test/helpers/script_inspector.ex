defmodule ScenicWidgets.TestHelpers.ScriptInspector do
  @moduledoc """
  Test helper for inspecting rendered Scenic content in Widget Workbench.

  Provides utilities to examine what's actually rendered to the screen,
  enabling true black-box testing of GUI components.
  """

  require Logger

  @doc """
  Checks if the rendered text output is empty (user content only).
  """
  def rendered_text_empty?() do
    get_user_content() |> Enum.empty?()
  end

  @doc """
  Checks if the rendered output contains the specified text (user content only).
  For TextField testing, this filters out Widget Workbench UI.
  """
  def rendered_text_contains?(expected_text) do
    user_content = get_user_content()
    IO.puts("🔍 ScriptInspector: Looking for '#{expected_text}' in user_content:")
    IO.inspect(user_content, label: "User content list", limit: 10)

    result = Enum.any?(user_content, fn text ->
      String.contains?(text, expected_text)
    end)

    IO.puts("🔍 Found: #{result}")
    result
  end

  @doc """
  Gets the full rendered text as a string for inspection.
  Includes all text (for UI verification).
  """
  def get_rendered_text_string() do
    try do
      script_data = get_script_table_directly()

      # Flatten all script entries to get all draw commands
      all_commands = script_data
      |> Enum.flat_map(fn
        {_id, commands, _pid} -> commands
        commands when is_list(commands) -> commands
        _ -> []
      end)

      all_commands
      |> extract_text_primitives()
      |> Enum.map(&extract_text_content/1)
      |> Enum.join(" ")
      |> String.trim()
    rescue
      error ->
        Logger.warn("Failed to get rendered text: #{Exception.message(error)}")
        ""
    end
  end

  @doc """
  Gets user-entered content only (filters out all GUI elements).
  """
  def get_user_content() do
    try do
      script_data = get_script_table_directly()

      all_commands = script_data
      |> Enum.flat_map(fn
        {_id, commands, _pid} -> commands
        commands when is_list(commands) -> commands
        _ -> []
      end)

      all_text = all_commands
      |> extract_text_primitives()
      |> Enum.map(&extract_text_content/1)

      IO.puts("🔍 ALL text primitives (#{length(all_text)}): #{inspect(all_text, limit: :infinity)}")

      filtered = all_text
      |> Enum.reject(&is_widget_workbench_ui?/1)
      |> Enum.reject(&is_common_gui_element?/1)

      IO.puts("🔍 After filtering (#{length(filtered)}): #{inspect(filtered, limit: :infinity)}")

      filtered
    rescue
      error ->
        Logger.warn("Failed to get user content: #{Exception.message(error)}")
        []
    end
  end

  @doc """
  Get the script table directly from the viewport without going through ScenicMcp.Probes.
  This works in test environments where ScenicMcp may not be fully available.
  Uses configured viewport name from scenic_mcp config.
  """
  def get_script_table_directly() do
    # Get viewport name from config (allows test and dev to run simultaneously)
    viewport_name = Application.get_env(:scenic_mcp, :viewport_name, :main_viewport)

    case Scenic.ViewPort.info(viewport_name) do
      {:ok, vp_info} ->
        # Get the script table reference from viewport info
        script_table = vp_info.script_table

        # Read all entries from the ETS table
        :ets.tab2list(script_table)

      _error ->
        []
    end
  end

  @doc """
  Debug function to dump the script table contents.
  """
  def debug_script_table() do
    try do
      script_data = get_script_table_directly()

      IO.puts("\n=== SCRIPT TABLE DEBUG ===")
      IO.puts("Total script entries: #{length(script_data)}")

      script_data
      |> Enum.with_index()
      |> Enum.each(fn {entry, index} ->
        IO.puts("Entry #{index}: #{inspect(entry, limit: :infinity)}")
      end)

      IO.puts("=== END SCRIPT TABLE ===\n")
    rescue
      error ->
        IO.puts("Failed to debug script table: #{Exception.message(error)}")
    end
  end

  @doc """
  Gets statistics about the rendered content.
  """
  def get_render_stats() do
    try do
      script_data = get_script_table_directly()

      text_primitives = extract_text_primitives(script_data)
      rect_primitives = extract_rect_primitives(script_data)

      %{
        total_script_entries: length(script_data),
        text_primitives_count: length(text_primitives),
        rect_primitives_count: length(rect_primitives),
        total_text_length: get_rendered_text_string() |> String.length()
      }
    rescue
      error ->
        Logger.warn("Failed to get render stats: #{Exception.message(error)}")
        %{error: Exception.message(error)}
    end
  end

  # Private helper functions

  defp extract_text_primitives(script_data) do
    script_data
    |> Enum.filter(&is_text_primitive?/1)
  end

  defp extract_rect_primitives(script_data) do
    script_data
    |> Enum.filter(&is_rect_primitive?/1)
  end

  defp is_text_primitive?(entry) do
    case entry do
      {_id, :text, _data, _opts} -> true
      {:text, _data, _opts} -> true
      %{type: :text} -> true
      {:draw_text, _text} -> true
      _ -> false
    end
  end

  defp is_rect_primitive?(entry) do
    case entry do
      {_id, :rect, _data, _opts} -> true
      {:rect, _data, _opts} -> true
      %{type: :rect} -> true
      _ -> false
    end
  end

  defp extract_text_content(entry) do
    case entry do
      {_id, :text, text_data, _opts} when is_binary(text_data) -> text_data
      {:text, text_data, _opts} when is_binary(text_data) -> text_data
      %{type: :text, data: text_data} when is_binary(text_data) -> text_data
      {:draw_text, text} when is_binary(text) -> text
      _ -> ""
    end
  end

  # Filter out Widget Workbench UI elements
  defp is_widget_workbench_ui?(text) when is_binary(text) do
    workbench_ui_patterns = [
      # Main UI text
      "Widget Workbench",
      "Design & test Scenic components",
      "New Widget",
      "Load Component",
      "Reset Scene",
      # Button/coordinate labels
      "A:", "B:", "C:", "D:",
      # Component modal text
      "Select Component",
      "Failed to load:",
      "function",
      "is undefined",
      "(module",
      "is not available)",
      "(Component isolation working!)",
      # Common error patterns
      "Error:",
      "undefined",
      "not available"
    ]

    # Check for exact or partial matches
    matches_pattern = Enum.any?(workbench_ui_patterns, fn pattern ->
      String.contains?(text, pattern) or text == pattern
    end)

    # Filter coordinate patterns like "(600, 545)"
    is_coordinate = String.match?(text, ~r/^\(\d+,\s*\d+\)$/)

    # Filter single special characters that are UI symbols
    is_symbol = String.length(text) == 1 and text in ["+", "×", "◊", "⋮", "|", "-", "=", "*"]

    result = matches_pattern or is_coordinate or is_symbol

    if result and String.length(text) > 10 do
      IO.puts("🔍 FILTERED OUT (workbench UI): '#{text}' (pattern=#{matches_pattern}, coord=#{is_coordinate}, symbol=#{is_symbol})")
    end

    result
  end

  defp is_widget_workbench_ui?(_), do: false

  # Filter out common GUI elements (similar to quillex)
  defp is_common_gui_element?(text) when is_binary(text) do
    # Font hashes (long alphanumeric strings with multiple underscores/dashes AND numbers)
    # Example: "Roboto_Mono_Regular_0abc123def456"
    has_multiple_separators = (String.split(text, "_") |> length() >= 3) or
                              (String.split(text, "-") |> length() >= 3)
    font_hash = String.length(text) > 30 and
                String.match?(text, ~r/^[A-Za-z0-9_-]+$/) and
                String.match?(text, ~r/[0-9]/) and
                has_multiple_separators

    # Script IDs (UUIDs or similar)
    script_id = String.contains?(text, "-") and
                String.length(text) > 10 and
                String.match?(text, ~r/^[A-Za-z0-9_-]+$/) and
                length(String.split(text, "-")) >= 3

    # Internal IDs (_something_)
    internal_id = String.starts_with?(text, "_") and String.ends_with?(text, "_")

    result = font_hash or script_id or internal_id

    if result and String.length(text) > 10 do
      IO.puts("🔍 FILTERED OUT (common GUI): '#{text}' (font=#{font_hash}, script=#{script_id}, internal=#{internal_id})")
    end

    result
  end

  defp is_common_gui_element?(_), do: false
end
