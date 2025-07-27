#!/usr/bin/env elixir

# Simple test to start Widget Workbench and load Menu Bar

# Start Widget Workbench
IO.puts("🎯 Starting Widget Workbench...")
{:ok, _pid} = WidgetWorkbench.start()
Process.sleep(2000)

# Check if viewport is registered
IO.puts("\n📋 Checking registered processes...")
viewport_registered = Process.whereis(:main_viewport) != nil
driver_registered = Process.whereis(:scenic_driver) != nil
IO.puts("  Viewport registered: #{viewport_registered}")
IO.puts("  Driver registered: #{driver_registered}")

# Try to use ScenicMcp.Probes directly
if Code.ensure_loaded?(ScenicMcp.Probes) do
  IO.puts("\n🔌 ScenicMcp.Probes is available")
  
  try do
    # Take a screenshot to see current state
    IO.puts("📸 Taking screenshot of initial state...")
    ScenicMcp.Probes.take_screenshot("initial_state")
    
    # Click Load Component button (right pane, calculated position)
    IO.puts("\n🖱️  Clicking Load Component button...")
    ScenicMcp.Probes.send_mouse_click(900, 290)
    Process.sleep(1000)
    
    # Take screenshot after click
    ScenicMcp.Probes.take_screenshot("after_load_click")
    
    # Click Menu Bar in modal (should be around 4th position)
    IO.puts("🖱️  Clicking Menu Bar in modal...")
    ScenicMcp.Probes.send_mouse_click(600, 280)
    Process.sleep(1000)
    
    # Take final screenshot
    ScenicMcp.Probes.take_screenshot("menubar_loaded")
    
    IO.puts("\n✅ Test completed! Check screenshots in current directory.")
  rescue
    error ->
      IO.puts("\n❌ Error during test: #{inspect(error)}")
  end
else
  IO.puts("\n⚠️  ScenicMcp.Probes not available")
end

# Keep the process alive
IO.puts("\n💡 Widget Workbench is running. Press Ctrl+C to exit.")
Process.sleep(:infinity)