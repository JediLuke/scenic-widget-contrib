#!/usr/bin/env elixir

# Test script to run Widget Workbench and test MenuBar component

IO.puts("Starting Widget Workbench to test MenuBar component...")

# Compile the project first
Mix.Task.run("compile")

# Start the application
Application.ensure_all_started(:scenic_widget_contrib)

# Start the Widget Workbench
case WidgetWorkbench.start() do
  {:ok, pid} ->
    IO.puts("Widget Workbench started successfully!")
    IO.puts("PID: #{inspect(pid)}")
    IO.puts("")
    IO.puts("Test the MenuBar component:")
    IO.puts("- Hover over menu items")
    IO.puts("- Click to open dropdowns")
    IO.puts("- Click menu items to see events logged")
    IO.puts("")
    IO.puts("Press Ctrl+C to exit...")
    
    # Keep the script running
    Process.sleep(:infinity)
    
  {:error, reason} ->
    IO.puts("Failed to start Widget Workbench: #{inspect(reason)}")
end