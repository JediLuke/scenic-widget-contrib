# Scenic Sidebar Component - Development Session Prompt

## Quick Start

I'm developing a hierarchical sidebar component for Flamelex using Spex-Driven Development. The component needs to support 5 levels of nesting, expand/collapse, hover states, scrolling, and search - similar to hexdocs or MS Word's navigation pane.

## Technical implementation report

A report with the entirity of our implementation plan is available at ./technical-implementation-report.md  

## Current Status

See the file dev-log.md for an up to date status report

## Key Files

```
/lib/gui/components/sidebar/
  ├── sidebar.ex              # Main component
  ├── state.ex               # State management  
  ├── renderer.ex            # Rendering logic
  └── input_handler.ex       # Input handling

/test/spex/sidebar/
  ├── phase1_basic_structure_spex.exs
  ├── phase2_expand_collapse_spex.exs
  └── ... (one per phase)
```

## Critical Patterns to Remember

### ✅ ALWAYS DO
```elixir
# Mouse input - use input style on primitives
|> Scenic.Primitives.group(
  fn g -> ... end,
  id: {:sidebar_item, path},
  input: [:cursor_button, :cursor_pos]  # THIS IS KEY!
)

# Performance - pre-render and toggle visibility
Graph.modify(graph, id, &Primitives.update_opts(&1, hidden: !visible))

# Keyboard - request_input is OK (needs global capture)
request_input(scene, [:key, :cursor_scroll])
```

### ❌ NEVER DO
```elixir
# NEVER capture mouse globally - breaks other components!
request_input(scene, [:cursor_button])  # NO!

# Don't re-render everything on state change
render(new_state)  # Avoid - use Graph.modify instead
```

## Today's Workflow

1. **Run Current Phase Spex**
   ```bash
   mix spex test/spex/sidebar/phase[X]_[feature]_spex.exs
   ```

2. **Observe Failures**
   ```
   ❌ Expected: [what]
      Got: [what]
   ```

3. **Implement Minimal Fix**
   - What does the error tell us?
   - What's the smallest change to make it pass?

4. **Verify Spex Pass**
   ```bash
   mix spex test/spex/sidebar/phase[X]_[feature]_spex.exs
   ```

5. **Update Dev Log**
   - Record what failed
   - Document the fix
   - Note any insights

## Component Architecture

```
User Input → InputHandler → State Update → Renderer → Graph Update
     ↓                                          ↑
     └──────────── Visual Feedback ─────────────┘
```

## Current Implementation Checklist

### Phase 1: Basic Structure ✓□
- [ ] Module structure with validate/init
- [ ] Basic rendering of flat items
- [ ] Nested rendering with indentation
- [ ] Proper frame/bounds handling

### Phase 2: Expand/Collapse □
- [ ] Expand icons for parents
- [ ] Click handler for icons
- [ ] Toggle visibility of children
- [ ] Icon rotation animation

### Phase 3: Mouse Interaction □
- [ ] Hover state tracking
- [ ] Selection state
- [ ] Click handlers (using input style!)
- [ ] No blocking of other components

### Phase 4: Keyboard Navigation □
- [ ] Arrow key navigation
- [ ] Expand/collapse with arrows
- [ ] Enter to activate
- [ ] Proper focus management

### Phase 5: Scrolling & Performance □
- [ ] Scroll input handling
- [ ] Viewport culling
- [ ] Constrained scrolling
- [ ] 1000+ item performance

### Phase 6: Selection & Actions □
- [ ] Selection persistence
- [ ] Action execution
- [ ] Parent notification
- [ ] State memory

### Phase 7: Search □
- [ ] Search UI
- [ ] Filter logic
- [ ] Auto-expansion
- [ ] State restoration

### Phase 8: Polish □
- [ ] Edge cases
- [ ] Depth limits
- [ ] Rapid interactions
- [ ] Accessibility

## Quick Debug Commands

```elixir
# In IEx - inspect current state
:sys.get_state(sidebar_pid)

# Take screenshot for debugging
ScenicMcp.Probes.take_screenshot("debug_#{DateTime.utc_now()}")

# Check what's actually rendered
ScriptInspector.list_all_elements()

# Verify element bounds
ScriptInspector.get_element_bounds({:sidebar_item, [:file, :new]})
```

## Questions to Answer

1. What spex is currently failing?
2. What's the exact error message?
3. What code makes this spex pass?
4. Does it follow our patterns?
5. Does it break anything else?

---

**Remember**: Each spex failure is a gift - it tells us EXACTLY what to build next. Trust the process!

---

P.S. Don't forget to update the dev log as we go!