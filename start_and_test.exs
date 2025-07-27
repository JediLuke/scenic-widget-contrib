# Start Widget Workbench
IO.puts("🎯 Starting Widget Workbench...")
{:ok, _pid} = WidgetWorkbench.start()
Process.sleep(2000)

# Check registration
viewport_registered = Process.whereis(:main_viewport) != nil
driver_registered = Process.whereis(:scenic_driver) != nil
IO.puts("📋 Viewport registered: #{viewport_registered}")
IO.puts("📋 Driver registered: #{driver_registered}")

if viewport_registered and Code.ensure_loaded?(ScenicMcp.Probes) do
  IO.puts("\n🔌 Using ScenicMcp to load Menu Bar...")
  
  try do
    # Click Load Component button
    IO.puts("🖱️  Clicking Load Component...")
    ScenicMcp.Probes.send_mouse_click(900, 290)
    Process.sleep(1000)
    
    # Click Menu Bar in modal
    IO.puts("🖱️  Selecting Menu Bar...")
    ScenicMcp.Probes.send_mouse_click(600, 280)
    Process.sleep(1000)
    
    # Take screenshot
    screenshot_path = ScenicMcp.Probes.take_screenshot("menubar_loaded")
    IO.puts("📸 Screenshot saved: #{screenshot_path}")
    
    IO.puts("\n✅ Menu Bar should be loaded!")
    IO.puts("💡 You can now run the spex test with: mix spex test/spex/menu_bar_issues_spex.exs")
  rescue
    error ->
      IO.puts("❌ Error: #{inspect(error)}")
  end
else
  IO.puts("⚠️  Either viewport not registered or ScenicMcp not available")
end

# Keep running
IO.puts("\n💻 IEx session ready. Widget Workbench is running.")
