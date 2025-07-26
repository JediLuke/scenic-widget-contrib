# MenuBar Component Requirements & Status

## Current Progress Summary

We've made significant progress on the MenuBar component:
- ✅ Basic menu structure working (File, Edit, View menus)
- ✅ Dropdown menus functional with click activation
- ✅ Sub-menus rendering with triangle indicators (replaced unicode ►)
- ✅ Hover navigation between menu items
- ✅ Click-outside detection in Widget Workbench
- ✅ Grace area for diagonal mouse movement
- ✅ Prevention of orphaned sub-menus
- ✅ Hover activation mode configuration added

## Outstanding Issues (Defects)

### 1. Text Alignment Issues
- **Issue**: Text not vertically centered in dropdown menus
- **Location**: Both menubar headers and dropdown items
- **Fix needed**: Adjust text y-coordinates to center within item heights

### 2. Sub-Sub-Menu Navigation
- **Issue**: Cannot hover into sub-sub-menus (mouse movement breaks)
- **Current**: Sub-sub-menus render but aren't accessible
- **Fix needed**: Extend grace area logic for nested sub-menus

### 3. Arrow Indicator Alignment
- **Issue**: Triangle arrows need vertical centering
- **Location**: Sub-menu indicators in dropdowns
- **Fix needed**: Adjust triangle y-coordinates

### 4. Text Overflow Handling
- **Issue**: Long menu text exceeds menu width
- **Examples**: "My project" and other long labels
- **Fix needed**: Implement text truncation or dynamic width adjustment

### 5. Unrenderable Character
- **Issue**: "My project" item shows unrenderable character
- **Fix needed**: Clean menu data or handle special characters

### 6. Click Feedback
- **Issue**: No visual confirmation when menu item is clicked
- **Fix needed**: Add indicator in test scene to show clicked items

### 7. Mouse-Out Behavior
- **Issue**: Moving mouse far outside doesn't reset menubar
- **Fix needed**: Implement proper boundary detection

### 8. Escape Key Support
- **Issue**: Escape key doesn't close menus
- **Fix needed**: Scene-level input handling to send :close_all_menus

## Configuration Options Needed

### 1. Activation Mode (partially implemented)
- **hover_activate**: true/false - hover vs click to open main menus
- **Status**: Logic implemented, needs testing

### 2. Menu Width Options (not implemented)
- **width_mode**: :fixed | :auto | :fit_content
- **min_width**: minimum pixel width
- **max_width**: maximum pixel width
- **text_wrap**: true/false for long text

### 3. Visual Customization
- **text_padding**: spacing around text
- **arrow_style**: triangle size/position options
- **separator_support**: for menu dividers

## Functional Requirements

1. **Menu Item Clicks**
   - Must send {:menu_item_clicked, item_id} to parent
   - Works for all levels (main items, sub-items, sub-sub-items)
   - Menu should close after selection

2. **Keyboard Navigation** (future)
   - Arrow keys to navigate
   - Enter to select
   - Escape to close

3. **Mouse Behavior**
   - Hover to show sub-menus
   - Click to activate items
   - Grace area for diagonal movement
   - Click-outside to close all

## Test Coverage Needed

1. All defects mentioned above
2. Configuration options
3. Multi-level menu navigation
4. Edge cases (empty menus, single items, etc.)
5. Performance with many menu items

## Files Modified in This Session

### Core Component Files
- `lib/components/menu_bar/optimized_renderizer.ex` - Rendering logic
- `lib/components/menu_bar/reducer.ex` - State management
- `lib/components/menu_bar/state.ex` - State structure

### Test Files
- `test/spex/menu_bar_comprehensive_spex.exs` - Main test suite
- `test/spex/menu_bar_fixes_test_spex.exs` - Quick verification tests

### Scene Files
- `lib/widget_workbench/widget_wkb_scene.ex` - Click-outside handling
- `test/hover_activate_test_scene.ex` - Hover mode testing (created)

## Next Steps

1. Fix the critical defects (text centering, sub-sub-menu navigation)
2. Add visual feedback for clicks
3. Implement escape key handling
4. Complete configuration options
5. Update comprehensive spex with all scenarios
6. Performance optimization if needed
7. Documentation update