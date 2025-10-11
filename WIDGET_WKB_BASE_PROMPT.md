# Widget Workbench Base Prompt

This file provides guidance for AI assistants working on the Widget Workbench project.

## Project Overview

Widget Workbench is a visual development tool for designing and testing Scenic GUI components in real-time. It provides a live preview environment where developers can load, test, and iterate on Scenic widgets.

## Key Information

### MCP Servers

**Scenic MCP Server**:
- **Port**: 9996 (Widget Workbench runs Scenic MCP on port 9996)
- **Purpose**: Enables programmatic control and testing of the GUI via Model Context Protocol
- **Connection**: Use `mcp__scenic-mcp__connect_scenic(port: 9996)` to connect
- **Key Tools**:
  - `click_element(element_id)` - Click elements by semantic ID
  - `send_keys(text)` / `send_keys(key, modifiers)` - Send keyboard input
  - `take_screenshot()` - Capture current display
  - `inspect_viewport()` - Get text-based UI structure
  - `find_clickable_elements()` - Discover all clickable elements

**Tidewave MCP Server**:
- **Port**: 4000 (Elixir project evaluation and introspection)
- **Purpose**: Provides Elixir code evaluation, documentation lookup, and project introspection
- **Key Tools**:
  - `project_eval(code)` - Evaluate Elixir code in project context
  - `get_docs(reference)` - Get documentation for modules/functions
  - `get_source_location(reference)` - Find source file locations
  - `get_logs(tail, grep)` - Retrieve application logs

### Project Structure
```
scenic-widget-contrib/
├── lib/
│   ├── widget_workbench/
│   │   ├── widget_wkb_scene.ex    # Main scene (root GUI state)
│   │   └── components/
│   │       └── modal.ex           # Component selection modal
│   ├── components/                # Reusable widget library
│   │   ├── buttons/
│   │   ├── menu_bar/
│   │   ├── side_nav/
│   │   └── ...
│   └── layout_components/
├── test/spex/                     # Executable specifications
└── mix.exs
```

### Architecture

**GUI State Management**:
- All GUI state lives in `lib/widget_workbench/widget_wkb_scene.ex`
- Scene holds state in `assigns` map
- Components register callbacks for state updates
- Input flows: Scenic → Scene → Input Handler → Reducer → Components

**Key State Fields** (in `widget_wkb_scene.ex`):
- `selected_component` - Currently loaded component module
- `show_modal` - Boolean for component selection modal
- `click_viz` - Click visualization state (for debugging)
- `window_size` - Current viewport dimensions

### Development Workflow

**Starting Widget Workbench**:
```bash
cd scenic-widget-contrib
mix deps.get
mix compile
iex -S mix  # Starts with MCP server on port 9996
```

**Testing with Scenic MCP**:
```elixir
# Connect to running app
connect_scenic(port: 9996)

# Interact with UI
click_element(element_id: "load_component_button")
inspect_viewport()
take_screenshot()
```

**Hot Reloading**:
- Code changes auto-reload via `exsync`
- Scene changes may require manual refresh
- NIFs (like Scenic.Math.Matrix) require full restart

### Common Tasks

**Adding a New Widget**:
1. Create component module in `lib/components/`
2. Implement `init/3`, `render/2`, `handle_input/3`
3. Add to component list in `widget_wkb_scene.ex` (`available_components/0`)
4. Test in Widget Workbench via "Load Component" button

**Debugging Input Issues**:
- Use `observe_input/3` for non-consuming observation
- Parent scene should NOT consume events if children need them
- Check `request_input/2` calls - must request input types to receive them
- Hit-testing requires primitives in `input_lists` with correct transforms

**Common Gotchas**:
- Button components expect `id` parameter to match primitive ID (or `:btn` default)
- Components in parent's input_list have empty types `[]` - this is intentional
- Parent scenes requesting cursor input should not consume it in `handle_input`
- Coordinate systems: global coords → parent coords → local coords via transforms

### Recent Fixes

**Button Click Issue (Fixed 2025-10-11)**:
- **Problem**: Buttons with custom IDs weren't receiving click events
- **Root Cause**: `Scenic.Component.Button.handle_input` hardcoded pattern match on `id: :btn`
- **Fix**: Changed pattern match to accept any ID matching the button's assigned ID
- **Location**: `/Users/luke/workbench/flx/scenic_local/lib/scenic/component/button.ex` lines 319, 360

### Key Files

**Main Scene**:
- `lib/widget_workbench/widget_wkb_scene.ex` - Root scene, all GUI state and logic

**Component Library**:
- `lib/components/buttons/` - Button widgets
- `lib/components/menu_bar/` - Menu bar components
- `lib/components/side_nav/` - Navigation widgets
- `lib/layout_components/` - Layout helpers

**Testing**:
- `test/spex/` - Executable specifications for testing

### Dependencies

**Key Elixir Packages**:
- `scenic` - GUI framework (local modified version in `../scenic_local`)
- `scenic_driver_local` - Graphics driver
- `scenic_live_reload` - Hot reloading support
- `tidewave` - MCP tools for Elixir evaluation

**Scenic MCP** (for AI control):
- Lives in `../scenic_mcp` (sibling project)
- TypeScript MCP server → TCP bridge → Elixir GenServer → ViewPort
- Enables Puppeteer-like automation for Scenic apps

### Development Tips

**When Adding Features**:
1. Update scene state in `widget_wkb_scene.ex` assigns
2. Add reducer function to handle state changes
3. Update render functions to reflect new state
4. Add input handlers if needed
5. Test with Scenic MCP automation

**Input Routing Order**:
1. Driver sends input to ViewPort
2. ViewPort checks if input type in `requested_inputs`
3. `do_listed_input` (hit-testing) runs FIRST
4. `do_requested_input` (delivers to requesting scenes) runs SECOND
5. Scenes call `observe_input` then `handle_input`

**Semantic Element Registration**:
```elixir
# Register clickable elements for MCP
Scenic.ViewPort.register_semantic(
  viewport,
  :_root_,
  :my_button_id,
  %{
    type: :button,
    label: "My Button",
    clickable: true,
    bounds: %{left: x, top: y, width: w, height: h}
  }
)
```

### Troubleshooting

**App won't start**:
- Check port 9996 isn't in use: `lsof -i :9996`
- Ensure scenic_driver_local compiled: `cd ../scenic_driver_local && make`
- Check Elixir version: `elixir --version` (needs 1.12+)

**Clicks not working**:
- Verify element registered with MCP: `find_clickable_elements()`
- Check input_lists in ViewPort state
- Ensure parent scene doesn't consume events
- Verify button ID matches primitive ID

**Hot reload issues**:
- Full restart needed for NIF changes (scenic_local)
- Scene state persists across reloads
- Use `mix compile --force` if changes not picked up

### Resources

- **Scenic Docs**: https://hexdocs.pm/scenic/
- **Scenic GitHub**: https://github.com/boydm/scenic
- **Project Root**: `/Users/luke/workbench/flx/`
