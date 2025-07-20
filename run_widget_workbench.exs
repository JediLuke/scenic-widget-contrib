#!/usr/bin/env elixir

# Script to run the Widget Workbench

defmodule WidgetWorkbenchApp do
  @moduledoc """
  Simple application to run the Widget Workbench scene
  """
  
  def start do
    IO.puts("🎯 Starting Widget Workbench...")
    
    # Configure viewport
    viewport_config = %{
      name: :main_viewport,
      size: {1200, 800},
      default_scene: {WidgetWorkbench.Scene, []},
      drivers: [
        %{
          module: Scenic.Driver.Local,
          name: :local,
          window: [
            resizeable: true,
            title: "Widget Workbench"
          ]
        }
      ]
    }
    
    # Start the viewport
    {:ok, _pid} = Scenic.ViewPort.start_link([viewport_config])
    
    IO.puts("✅ Widget Workbench is running!")
    IO.puts("   - Press 'n' to create a new component")
    IO.puts("   - Use the UI to develop and test Scenic components")
    
    # Keep the script running
    Process.sleep(:infinity)
  end
end

# Run the application
WidgetWorkbenchApp.start()