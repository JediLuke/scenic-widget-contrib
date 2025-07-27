#!/usr/bin/env elixir
# Complete test runner for menu_bar_issues_spex

IO.puts("🚀 Starting Menu Bar Issues Test Runner")
IO.puts("=====================================")

# Ensure MCP server is not running
IO.puts("\n1️⃣ Cleaning up old processes...")
System.cmd("pkill", ["-f", "scenic_mcp"], stderr_to_stdout: true)
Process.sleep(1000)

# Start MCP server if not already running
IO.puts("\n2️⃣ Checking MCP server...")
case ScenicMcp.Server.start_link(port: 9999) do
  {:ok, _server} ->
    IO.puts("✅ MCP server started on port 9999")
  {:error, {:already_started, _}} ->
    IO.puts("✅ MCP server already running on port 9999")
end

# Start Widget Workbench
IO.puts("\n3️⃣ Starting Widget Workbench...")
{:ok, _pid} = WidgetWorkbench.start()
Process.sleep(3000)

# Verify viewport is registered
viewport_registered = Process.whereis(:main_viewport) != nil
IO.puts("✅ Viewport registered: #{viewport_registered}")

if viewport_registered do
  IO.puts("\n4️⃣ Loading Menu Bar component...")
  
  # Take initial screenshot
  ScenicMcp.Probes.take_screenshot("01_initial_state")
  
  # Click Load Component button
  IO.puts("   Clicking Load Component button...")
  ScenicMcp.Probes.send_mouse_click(900, 290)
  Process.sleep(1500)
  
  # Take screenshot of modal
  ScenicMcp.Probes.take_screenshot("02_modal_open")
  
  # Menu Bar should be at index 4 (5th item) in the components list
  # Modal top: ~240, header: 60px, each item: 45px (40px + 5px margin)
  menu_bar_y = 240 + 60 + (4 * 45) + 20
  menu_bar_x = 600
  
  IO.puts("   Clicking Menu Bar at (#{menu_bar_x}, #{menu_bar_y})...")
  ScenicMcp.Probes.send_mouse_click(menu_bar_x, menu_bar_y)
  Process.sleep(2000)
  
  # Take screenshot to verify Menu Bar loaded
  ScenicMcp.Probes.take_screenshot("03_menubar_loaded")
  
  IO.puts("✅ Menu Bar component loaded!")
  
  # Now run the spex test
  IO.puts("\n5️⃣ Running menu_bar_issues_spex test...")
  IO.puts("=" |> String.duplicate(50))
  
  # Load test helpers
  Code.require_file("test/test_helpers/script_inspector.ex")
  Code.require_file("test/test_helpers/semantic_ui.ex")
  
  # Run the test file
  Mix.Task.run("test", ["test/spex/menu_bar_issues_spex.exs", "--no-start"])
  
else
  IO.puts("❌ Failed to register viewport!")
end

IO.puts("\n✅ Test run complete!")
IO.puts("📸 Check screenshots: 01_initial_state.png, 02_modal_open.png, 03_menubar_loaded.png")