#!/usr/bin/env elixir

# Ensure application is compiled
System.cmd("mix", ["compile"], stderr_to_stdout: true)

# Start the application
{:ok, _} = Application.ensure_all_started(:scenic_widget_contrib)

# Check if scenic_mcp is available
case Code.ensure_loaded(ScenicMcp.Server) do
  {:module, _} ->
    # Start MCP server on port 9999
    case ScenicMcp.Server.start_link(port: 9999) do
      {:ok, _server} ->
        IO.puts("✅ MCP server started on port 9999")
      {:error, {:already_started, _}} ->
        IO.puts("ℹ️  MCP server already running on port 9999")
      error ->
        IO.puts("⚠️  Failed to start MCP server: #{inspect(error)}")
    end
  {:error, _} ->
    IO.puts("⚠️  scenic_mcp not available, starting without MCP support")
end

# Start the Widget Workbench
case WidgetWorkbench.start() do
  {:ok, _pid} ->
    IO.puts("✅ Widget Workbench started successfully!")
    IO.puts("")
    IO.puts("📋 To run the menu_bar_issues_spex test:")
    IO.puts("   mix spex test/spex/menu_bar_issues_spex.exs")
    IO.puts("")
    IO.puts("🔌 MCP Control:")
    IO.puts("   - MCP server running on port 9999")
    IO.puts("   - You can now connect using scenic_mcp tools")
    IO.puts("")
  error ->
    IO.puts("❌ Failed to start Widget Workbench: #{inspect(error)}")
    System.halt(1)
end

# Keep the process alive
Process.sleep(:infinity)