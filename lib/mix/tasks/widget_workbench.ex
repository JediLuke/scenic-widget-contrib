defmodule Mix.Tasks.WidgetWorkbench do
  use Mix.Task
  
  @shortdoc "Start the Widget Workbench application"
  
  @moduledoc """
  Starts the Widget Workbench for developing Scenic components.
  
  ## Usage
  
      mix widget_workbench
  
  This will start a Scenic application with the Widget Workbench scene,
  allowing you to develop and test Scenic components interactively.
  """
  
  def run(_args) do
    Mix.Task.run("app.start")
    
    IO.puts("🎯 Starting Widget Workbench...")
    
    # Configure viewport with proper list format
    viewport_config = [
      name: :main_viewport,
      size: {1200, 800},
      theme: :dark,
      default_scene: {WidgetWorkbench.Scene, []},
      drivers: [
        [
          module: Scenic.Driver.Local,
          name: :local,
          window: [
            resizeable: true,
            title: "Widget Workbench"
          ],
          debug: false,
          cursor: true,
          antialias: true,
          layer: 0,
          opacity: 255,
          position: [
            scaled: false,
            centered: false,
            orientation: :normal
          ]
        ]
      ]
    ]
    
    # Start the viewport
    {:ok, _pid} = Scenic.ViewPort.start_link(viewport_config)
    
    IO.puts("✅ Widget Workbench is running!")
    IO.puts("   - Press 'n' to create a new component")
    IO.puts("   - Click '+' button to add widgets")
    IO.puts("   - Use the UI to develop and test Scenic components")
    
    # Keep the task running
    Process.sleep(:infinity)
  end
end