import Config

if System.get_env("PHX_SERVER") do
  config :angel_trading, AngelTradingWeb.Endpoint, server: true
end

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "example.com"
  port = String.to_integer(System.get_env("PORT") || "8080")

  config :angel_trading, AngelTradingWeb.Endpoint,
    adapter: Bandit.PhoenixAdapter,
    url: [host: host, port: 443, scheme: "https"],
    http: [
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
      port: port
    ],
    protocol_options: [max_header_value_length: 8192],
    secret_key_base: secret_key_base

  config :angel_trading, AngelTrading.Mailer,
    adapter: Swoosh.Adapters.Brevo,
    api_key: System.get_env("BREVO_API_KEY")

  config :swoosh, :api_client, Swoosh.ApiClient.Finch

  config :angel_trading,
    firebase_token: System.get_env("FIREBASE_TOKEN"),
    firebase_api: System.get_env("FIREBASE_API"),
    encryption_key: System.get_env("ENCRYPTION_KEY")

  # api_key, secret_key, proxy_url are stored per-client in Firebase (encrypted).
  # local_ip, mac_address, proxy_username, proxy_password are server-wide globals.
  # public_ip is derived at call-time from each client's proxy_url host.
  config :trade_galleon, TradeGalleon.Brokers.AngelOne,
    adapter: TradeGalleon.Brokers.AngelOne,
    local_ip: System.get_env("LOCAL_IP", "192.168.168.168"),
    mac_address: System.get_env("MAC_ADDRESS", "fe80::216e:6507:4b90:3719"),
    proxy_username: System.get_env("PROXY_USERNAME"),
    proxy_password: System.get_env("PROXY_PASSWORD")

  # api_key is per-client, passed at call-time. pub_sub_module/supervisor are global.
  config :trade_galleon, TradeGalleon.Brokers.AngelOne.WebSocket,
    adapter: TradeGalleon.Brokers.AngelOne.WebSocket,
    pub_sub_module: AngelTrading.PubSub,
    supervisor: AngelTrading.WebSocketSupervisor

  config :trade_galleon, TradeGalleon.Brokers.AngelOne.WebSocketOrderStatus,
    adapter: TradeGalleon.Brokers.AngelOne.WebSocketOrderStatus,
    pub_sub_module: AngelTrading.PubSub,
    supervisor: AngelTrading.WebSocketSupervisor

  config :langchain, google_ai_key: System.get_env("GOOGLE_API_KEY")
end
