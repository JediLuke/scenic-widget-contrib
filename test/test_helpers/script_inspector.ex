defmodule ScenicWidgets.TestHelpers.ScriptInspector do
  @moduledoc """
  Test helper for inspecting rendered Scenic content in Widget Workbench.
  
  Provides utilities to examine what's actually rendered to the screen,
  enabling true black-box testing of GUI components.
  
  This is adapted from Quillex's ScriptInspector for use with Widget Workbench.
  """

  require Logger

  @doc """
  Checks if the rendered text output is empty.
  """
  def rendered_text_empty?() do
    get_rendered_text_string() |> String.trim() == ""
  end

  @doc """
  Checks if the rendered output contains the specified text.
  """
  def rendered_text_contains?(expected_text) do
    rendered_content = get_rendered_text_string()
    String.contains?(rendered_content, expected_text)
  end

  @doc """
  Gets the full rendered text as a string for inspection.
  """
  def get_rendered_text_string() do
    try do
      script_data = ScenicMcp.Probes.script_table()
      
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
  Debug function to dump the script table contents.
  """
  def debug_script_table() do
    try do
      script_data = ScenicMcp.Probes.script_table()
      
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
      script_data = ScenicMcp.Probes.script_table()
      
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
end