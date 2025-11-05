defmodule ScenicWidgets.TextField.Reducer do
  @moduledoc """
  Pure state transition functions for TextField.

  Phase 1: Stub only
  Phase 2: Input handling (process_input/2)
  Phase 3: External actions (process_action/2)

  Returns:
  - {:noop, state} - State changed, no parent notification needed
  - {:event, event_data, state} - State changed, notify parent
  """

  alias ScenicWidgets.TextField.State

  @doc """
  Process raw Scenic input events (for direct input mode).
  Phase 2 implementation.
  """
  def process_input(state, _input) do
    # Phase 1: Stub - no input handling yet
    {:noop, state}
  end

  @doc """
  Process high-level actions (for external control mode).
  Phase 3 implementation.
  """
  def process_action(state, _action) do
    # Phase 1: Stub - no action handling yet
    {:noop, state}
  end

  # ===== HELPER FUNCTIONS (Phase 2+) =====
  # To be implemented in Phase 2
end
