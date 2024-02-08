# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Configures the endpoint
config :angel_trading, AngelTradingWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: AngelTradingWeb.ErrorHTML, json: AngelTradingWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: AngelTrading.PubSub,
  live_view: [signing_salt: "i/giY6p5"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :angel_trading, AngelTrading.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  default: [
    args: ~w(js/app.js
        --chunk-names=chunks/[name]-[hash] --splitting --format=esm --bundle --target=es2017 --minify
        --outdir=../priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "3.3.2",
  default: [
    args: ~w(
      --config=tailwind.config.js
      --input=css/app.css
      --output=../priv/static/assets/app.css
    ),
    cd: Path.expand("../assets", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

config :angel_trading,
  api_key: System.get_env("API_KEY"),
  firebase_token: System.get_env("FIREBASE_TOKEN"),
  firebase_api: System.get_env("FIREBASE_API"),
  encryption_key: System.get_env("ENCRYPTION_KEY")

config :trade_galleon, TradeGalleon.Brokers.AngelOne,
  adapter: TradeGalleon.Brokers.AngelOne,
  api_key: System.get_env("API_KEY"),
  local_ip: System.get_env("LOCAL_IP", "192.168.168.168"),
  public_ip: System.get_env("PUBLIC_IP", "106.193.147.98"),
  mac_address: System.get_env("MAC_ADDRESS", "fe80::216e:6507:4b90:3719"),
  secret_key: System.get_env("SECRET_KEY")

config :trade_galleon, TradeGalleon.Brokers.AngelOne.WebSocket,
  adapter: TradeGalleon.Brokers.AngelOne.WebSocket,
  api_key: System.get_env("API_KEY"),
  pub_sub_module: AngelTrading.PubSub,
  supervisor: AngelTrading.WebSocketSupervisor

config :tesla, adapter: Tesla.Adapter.Hackney

config :number,
  currency: [
    unit: "₹",
    precision: 2,
    delimiter: ",",
    separator: ".",
    # "₹30.00"
    format: "%u%n",
    # "(₹30.00)"
    negative_format: "-%u%n"
  ]

config :phoenix,
  static_compressors: [
    PhoenixBakery.Gzip,
    PhoenixBakery.Brotli,
    PhoenixBakery.Zstd
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
