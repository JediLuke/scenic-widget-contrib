#!/usr/bin/env elixir

# Run the Widget Workbench directly

# Set up the code paths
Code.prepend_path("_build/dev/lib/scenic_widget_contrib/ebin")
Code.prepend_path("_build/dev/lib/scenic/ebin")
Code.prepend_path("_build/dev/lib/scenic_driver_local/ebin")
Code.prepend_path("_build/dev/lib/font_metrics/ebin")
Code.prepend_path("_build/dev/lib/truetype_metrics/ebin")
Code.prepend_path("_build/dev/lib/ex_image_info/ebin")
Code.prepend_path("_build/dev/lib/nimble_options/ebin")
Code.prepend_path("_build/dev/lib/input_event/ebin")
Code.prepend_path("_build/dev/lib/scenic_mcp/ebin")
Code.prepend_path("_build/dev/lib/sexy_spex/ebin")
Code.prepend_path("_build/dev/lib/jason/ebin")

IO.puts("Starting Widget Workbench...")

# Start required applications
Application.ensure_all_started(:logger)
Application.ensure_all_started(:scenic)
Application.ensure_all_started(:scenic_driver_local)

# Configure viewport
viewport_config = %{
  name: :widget_workbench_viewport,
  size: {1200, 800},
  theme: :light,
  default_scene: {WidgetWorkbench.Scene, []},
  drivers: [
    %{
      module: Scenic.Driver.Local,
      name: :local,
      window: [
        resizeable: true,
        title: "Widget Workbench - MenuBar Test"
      ],
      on_close: :stop_viewport
    }
  ]
}

# Start the viewport
case Scenic.ViewPort.start_link(viewport_config) do
  {:ok, pid} ->
    IO.puts("✅ Widget Workbench is running!")
    IO.puts("")
    IO.puts("Test the MenuBar component:")
    IO.puts("- Hover over File, Edit, View, Help menus")
    IO.puts("- Click to open dropdown menus")
    IO.puts("- Click menu items to see events in console")
    IO.puts("")
    IO.puts("Press Ctrl+C twice to exit...")
    
    # Keep running
    Process.sleep(:infinity)
    
  {:error, reason} ->
    IO.puts("❌ Failed to start: #{inspect(reason)}")
end