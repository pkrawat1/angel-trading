import Config

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.

# ## Using releases
#
# If you use `mix release`, you need to explicitly enable the server
# by passing the PHX_SERVER=true when you start it:
#
#     PHX_SERVER=true bin/angel_trading start
#
# Alternatively, you can use `mix phx.gen.release` to generate a `bin/server`
# script that automatically sets the env var above.
if System.get_env("PHX_SERVER") do
  config :angel_trading, AngelTradingWeb.Endpoint, server: true
end

if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "4000")

  config :angel_trading, AngelTradingWeb.Endpoint,
    adapter: Bandit.PhoenixAdapter,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    protocol_options: [max_header_value_length: 8192],
    secret_key_base: secret_key_base

  # ## SSL Support
  #
  # To get SSL working, you will need to add the `https` key
  # to your endpoint configuration:
  #
  #     config :angel_trading, AngelTradingWeb.Endpoint,
  #       https: [
  #         ...,
  #         port: 443,
  #         cipher_suite: :strong,
  #         keyfile: System.get_env("SOME_APP_SSL_KEY_PATH"),
  #         certfile: System.get_env("SOME_APP_SSL_CERT_PATH")
  #       ]
  #
  # The `cipher_suite` is set to `:strong` to support only the
  # latest and more secure SSL ciphers. This means old browsers
  # and clients may not be supported. You can set it to
  # `:compatible` for wider support.
  #
  # `:keyfile` and `:certfile` expect an absolute path to the key
  # and cert in disk or a relative path inside priv, for example
  # "priv/ssl/server.key". For all supported SSL configuration
  # options, see https://hexdocs.pm/plug/Plug.SSL.html#configure/1
  #
  # We also recommend setting `force_ssl` in your endpoint, ensuring
  # no data is ever sent via http, always redirecting to https:
  #
  #     config :angel_trading, AngelTradingWeb.Endpoint,
  #       force_ssl: [hsts: true]
  #
  # Check `Plug.SSL` for all available options in `force_ssl`.

  # ## Configuring the mailer
  #
  # In production you need to configure the mailer to use a different adapter.
  # Also, you may need to configure the Swoosh API client of your choice if you
  # are not using SMTP. Here is an example of the configuration:
  #
  config :angel_trading, AngelTrading.Mailer,
    adapter: Swoosh.Adapters.Brevo,
    api_key: System.get_env("BREVO_API_KEY")

  #
  # For this example you need include a HTTP client required by Swoosh API client.
  # Swoosh supports Hackney and Finch out of the box:
  #
  config :swoosh, :api_client, Swoosh.ApiClient.Finch
  #
  # See https://hexdocs.pm/swoosh/Swoosh.html#module-installation for details.

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

  config :trade_galleon, TradeGalleon.Brokers.AngelOne.WebSocketOrderStatus,
    adapter: TradeGalleon.Brokers.AngelOne.WebSocketOrderStatus,
    pub_sub_module: AngelTrading.PubSub,
    supervisor: AngelTrading.WebSocketSupervisor
end
