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

    # No viewport exists, create a new one
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
      name: ScenicMcp.Config.viewport_name(),
      size: size,
      theme: :dark,
      default_scene: {WidgetWorkbench.Scene, []},
      drivers: [
        [
          module: Scenic.Driver.Local,
          name: :widget_wkb_scenic_driver,
          window: [
            resizeable: true,
            title: title
          ],
          on_close: :stop_viewport,
          debug: false,
          debugger: "",
          debug_fps: 0,
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
    case Process.whereis(:main_viewport) do
      nil ->
        IO.puts("Widget Workbench is not running")
        :ok

      pid ->
        IO.puts("Stopping Widget Workbench...")
        Process.exit(pid, :kill)
        # Wait for the process to actually stop
        wait_for_stop()
        :ok
    end
  end

  defp wait_for_stop(timeout \\ 1000) do
    case Process.whereis(:main_viewport) do
      nil ->
        :ok

      _pid when timeout <= 0 ->
        :timeout

      _pid ->
        Process.sleep(10)
        wait_for_stop(timeout - 10)
    end
  end

  @doc """
  Resets the Widget Workbench by stopping and restarting it.
  """
  def reset(opts \\ []) do
    IO.puts("🔄 Resetting Widget Workbench...")
    stop()
    Process.sleep(200)
    start(opts)
  end

  @doc """
  Hot reloads the scene without killing the viewport - smoother than reset.
  """
  def hot_reload do
    require Logger

    # Try to find the scene process instead of restarting it
    scene_pid = Process.whereis(:_widget_workbench_scene_)

    Logger.info("🔍 Looking for scene process: #{inspect(scene_pid)}")

    if scene_pid && Process.alive?(scene_pid) do
      Logger.info("🔥 Hot-reloading scene (sending message to #{inspect(scene_pid)})...")
      send(scene_pid, :hot_reload)
      Logger.info("✅ Hot reload message sent!")
    else
      Logger.info("❌ Scene process not found or not alive")
      # Fallback to set_root if we can't find the scene
      case Scenic.ViewPort.info(:main_viewport) do
        {:ok, viewport} ->
          Logger.info("🔥 Hot-reloading scene (restarting)...")
          Scenic.ViewPort.set_root(viewport, WidgetWorkbench.Scene)
          Logger.info("✅ Scene restarted with new code!")

        _ ->
          Logger.info("Widget Workbench is not running")
          :ok
      end
    end
  end

  @doc """
  Checks if the Widget Workbench is running.
  """
  def running? do
    case Process.whereis(:main_viewport) do
      nil -> false
      _pid -> true
    end
  end
end
