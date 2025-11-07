defmodule ScenicWidgets.TextField.WordWrapSpex do
  @moduledoc """
  TextField Word Wrap Specification

  ## Purpose
  This spex verifies togglable word wrap functionality for the TextField component:
  1. Text can be configured to wrap at container boundaries
  2. Wrapped text appears on multiple lines
  3. Word wrap can be toggled on/off
  4. Cursor positioning works correctly with wrapped text

  ## Feature Scope
  This spex covers word wrap functionality:
  - Text wraps when exceeding container width
  - Words break at appropriate boundaries
  - Line count increases when text wraps
  - Toggling word wrap updates display
  - Cursor navigation respects wrapped lines

  ## Success Criteria
  - Long text wraps to multiple visual lines
  - get_line_count() reflects wrapped line count
  - text_appears_on_line?() can verify wrap positions
  - Toggle updates rendering without losing content
  """

  use SexySpex

  # Load test helpers explicitly
  Code.require_file("test/helpers/script_inspector.ex")
  Code.require_file("test/helpers/semantic_ui.ex")

  alias ScenicWidgets.TestHelpers.{ScriptInspector, SemanticUI}

  setup_all do
    # Get test-specific viewport and driver names from config
    viewport_name = Application.get_env(:scenic_mcp, :viewport_name, :test_viewport)
    driver_name = Application.get_env(:scenic_mcp, :driver_name, :test_driver)

    # Ensure any existing test viewport is stopped first
    if viewport_pid = Process.whereis(viewport_name) do
      Process.exit(viewport_pid, :kill)
      Process.sleep(100)
    end

    # Start the Scenic application
    case Application.ensure_all_started(:scenic_widget_contrib) do
      {:ok, _apps} -> :ok
      {:error, {:already_started, :scenic_widget_contrib}} -> :ok
    end

    # Configure and start the viewport for Widget Workbench
    viewport_config = [
      name: viewport_name,
      size: {1200, 800},
      theme: :dark,
      default_scene: {WidgetWorkbench.Scene, []},
      drivers: [
        [
          module: Scenic.Driver.Local,
          name: driver_name,
          window: [
            resizeable: true,
            title: "Widget Workbench - TextField Word Wrap Test (Port 9998)"
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

    # Start the viewport
    {:ok, viewport_pid} = Scenic.ViewPort.start_link(viewport_config)

    # Wait for Widget Workbench to initialize
    Process.sleep(1500)

    # Cleanup on test completion
    on_exit(fn ->
      if pid = Process.whereis(viewport_name) do
        Process.exit(pid, :normal)
        Process.sleep(100)
      end
    end)

    {:ok, %{viewport_pid: viewport_pid, viewport_name: viewport_name, driver_name: driver_name}}
  end

  spex "TextField Word Wrap Functionality",
    description: "Verifies text wrapping behavior and toggle functionality",
    tags: [:textfield, :word_wrap, :rendering, :demo] do

    # Scenarios will be added during the live demo!
    # This skeleton is ready for implementation

  end
end
