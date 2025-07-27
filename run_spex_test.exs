#!/usr/bin/env elixir

# This script runs the spex test without starting scenic_mcp
# (assumes the server is already running)

# Ensure we're in the test environment
System.put_env("MIX_ENV", "test")

# Load the project
Mix.start()
Mix.Task.run("loadpaths")
Mix.Task.run("compile")

# Load test helpers
Code.require_file("test/test_helpers/script_inspector.ex")
Code.require_file("test/test_helpers/semantic_ui.ex")

# Load the spex framework
Code.append_path("../spex/lib")
Application.ensure_all_started(:sexy_spex)

# Run the test file
IO.puts("🎯 Running menu_bar_issues_spex.exs test...")
Code.require_file("test/spex/menu_bar_issues_spex.exs")

# Run the tests
ExUnit.configure(formatters: [ExUnit.CLIFormatter])
ExUnit.run()