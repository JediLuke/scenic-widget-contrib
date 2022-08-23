defmodule QuillEx.EventListener do
  use GenServer
  require Logger

  def start_link(_args) do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(_args) do
    Logger.debug("#{__MODULE__} initializing...")
    Process.register(self(), __MODULE__)
    EventBus.subscribe({__MODULE__, ["general"]})
    {:ok, %{}}
  end

  def process({:general = _topic, _id} = event_shadow) do

    event = EventBus.fetch_event(event_shadow)
    radix_state = QuillEx.RadixStore.get()

    case do_process(radix_state, event.data) do
      x when x in [:ok, :ignore] ->
        EventBus.mark_as_completed({__MODULE__, event_shadow})
      {:ok, ^radix_state} ->
        # Logger.debug "ignoring action, no change to radix_state..."
        EventBus.mark_as_completed({__MODULE__, event_shadow})
      {:ok, new_radix_state} ->
        QuillEx.RadixStore.put(new_radix_state)
        EventBus.mark_as_completed({__MODULE__, event_shadow})
    end
  end


  ## --------------------------------------------------------


  def do_process(radix_state, {reducer, {:action, a}}) when is_atom(reducer) do
    try do
      reducer.process(radix_state, a)
    rescue
      e in FunctionClauseError ->
        Logger.error "action: #{inspect a} failed to match for reducer: #{inspect reducer}"
        reraise e, __STACKTRACE__
    end
  end

  def do_process(radix_state, action) do
    details = %{radix_state: radix_state, action: action}
    Logger.debug "#{__MODULE__} ignoring action... #{inspect(details)}"
    :ignore
  end
end