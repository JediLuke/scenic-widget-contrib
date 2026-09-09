defmodule ScenicWidgets.Application do
  @moduledoc false

  use Application
  require Logger

  def start(_type, _args) do
    children = []

    # Add ScenicLiveReload to children in dev environment if not already started
    # children =
    #   if Mix.env() == :dev && !Process.whereis(ScenicLiveReload) do
    #     [{ScenicLiveReload, []}] ++ children
    #   else
    #     children
    #   end

    # Conditionally start Tidewave server for development
    children =
      children ++
        if Application.get_env(:scenic_widget_contrib, :environment) == :dev and Code.ensure_loaded?(Tidewave) and Code.ensure_loaded?(Bandit) do
          Logger.info("Starting Tidewave server on port 4067 for development")
          [{Bandit, plug: Tidewave, port: 4067}]
        else
          []
        end

    opts = [strategy: :one_for_one, name: ScenicWidgets.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
