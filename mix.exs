defmodule ScenicWidgets.MixProject do
  use Mix.Project

  def project do
    [
      app: :scenic_widget_contrib,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      preferred_cli_env: [
        spex: :test
      ]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ScenicWidgets.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:scenic, git: "https://github.com/ScenicFramework/scenic.git", tag: "v0.11.1", override: true},
      {:scenic, path: "../scenic", override: true},
      {:scenic_driver_local, git: "https://github.com/JediLuke/scenic_driver_local", branch: "flamelex_vsn", override: true},
      {:font_metrics, "~> 0.5"},
      {:ex_doc, "~> 0.25", only: :dev},
      {:earmark, "~> 1.4", only: :dev},
      # {:stream_data, "~> 1.0", only: :test},
      # Added dependencies for widget development
      {:scenic_mcp, path: "../scenic_mcp"},
      {:sexy_spex, path: "../spex", optional: true},
      {:scenic_live_reload, git: "https://github.com/axelson/scenic_live_reload.git", branch: "main", only: :dev},
      {:tidewave, "~> 0.1", only: :dev},
      {:bandit, "~> 1.0", only: :dev},
      {:pomodoro, path: "~/dev/pomodoro"}
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/test_helpers"]
  defp elixirc_paths(_), do: ["lib"]
end
