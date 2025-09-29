import Config

config :scenic, :assets, module: ScenicWidgets.Assets

# Use a different port for tests to avoid conflicts
config :scenic_mcp, port: 9998
