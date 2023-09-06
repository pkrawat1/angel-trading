import Config

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :angel_trading, AngelTradingWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "R95zjf1V28dRx0qJYzPG95E7LHVtBh0JbAFRLpUHssfAIxDq1qDbhi/y/5BZfw8W",
  server: false

# In test we don't send emails.
config :angel_trading, AngelTrading.Mailer,
  adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime
