defmodule WidgetWorkbench do
  @moduledoc """
  Main entry point for the Widget Workbench.
  
  Start the workbench from IEx with:
  
      iex> WidgetWorkbench.start()
  
  This will boot a Scenic viewport with the widget workbench scene,
  allowing you to develop and test Scenic components interactively.
  """
  
  @doc """
  Starts the Widget Workbench application.
  
  Options:
    - size: {width, height} tuple for viewport size (default: {1200, 800})
    - title: window title (default: "Widget Workbench")
  """
  def start(opts \\ []) do
    size = Keyword.get(opts, :size, {1200, 800})
    title = Keyword.get(opts, :title, "Widget Workbench")
    
    IO.puts("🎯 Starting Widget Workbench...")
    
    # First, ensure we have the driver dependency
    case Code.ensure_loaded(Scenic.Driver.Local) do
      {:module, _} ->
        start_viewport(size, title)
      {:error, _} ->
        IO.puts("❌ Error: scenic_driver_local is not available.")
        IO.puts("   Add {:scenic_driver_local, \"~> 0.11\"} to your deps")
        {:error, :missing_driver}
    end
  end
  
  defp start_viewport(size, title) do
    viewport_config = [
      name: :widget_workbench_viewport,
      size: size,
      theme: :dark,
      default_scene: {WidgetWorkbench.Scene, []},
      drivers: [
        [
          module: Scenic.Driver.Local,
          name: :local,
          window: [
            resizeable: true,
            title: title
          ],
          on_close: :stop_viewport,
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
    
    case Scenic.ViewPort.start_link(viewport_config) do
      {:ok, pid} ->
        IO.puts("✅ Widget Workbench is running!")
        IO.puts("")
        IO.puts("   Controls:")
        IO.puts("   - Press 'n' to create a new component")
        IO.puts("   - Click '+' button to add widgets")
        IO.puts("   - Use the UI to develop and test Scenic components")
        IO.puts("")
        IO.puts("   The viewport PID is: #{inspect(pid)}")
        IO.puts("   To stop: WidgetWorkbench.stop()")
        {:ok, pid}
        
      {:error, reason} ->
        IO.puts("❌ Failed to start viewport: #{inspect(reason)}")
        {:error, reason}
    end
  end
  
  @doc """
  Stops the Widget Workbench viewport.
  """
  def stop do
    case Process.whereis(:widget_workbench_viewport) do
      nil ->
        IO.puts("Widget Workbench is not running")
        :ok
      pid ->
        IO.puts("Stopping Widget Workbench...")
        Scenic.ViewPort.stop(pid)
        :ok
    end
  end
  
  @doc """
  Checks if the Widget Workbench is running.
  """
  def running? do
    case Process.whereis(:widget_workbench_viewport) do
      nil -> false
      _pid -> true
    end
  end
end