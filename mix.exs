defmodule AngelTrading.MixProject do
  use Mix.Project

  def project do
    [
      app: :angel_trading,
      version: "0.1.0",
      elixir: "~> 1.16.0",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {AngelTrading.Application, []},
      extra_applications:
        [
          :logger,
          :runtime_tools,
          :websockex
        ] ++
          if(Mix.env() == :dev,
            do: [
              :observer,
              :wx
            ],
            else: []
          )
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:phoenix, "~> 1.7.7"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 0.20.0"},
      {:floki, ">= 0.30.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.2"},
      {:esbuild, "~> 0.7", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.3"},
      {:finch, "~> 0.13"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 0.20"},
      {:jason, "~> 1.2"},
      {:tesla, "~> 1.4"},
      {:websockex, "~> 0.4.3"},
      {:plug_cowboy, "~> 2.5"},
      {:number, "~> 1.0"},
      {:timex, "~> 3.0"},
      {:trade_galleon, git: "https://github.com/pkrawat1/trade_galleon.git", branch: "master"},
      # {:trade_galleon, path: "../trade_galleon"},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:rustler, "~> 0.30.0", runtime: false},
      {:brotli, ">= 0.0.0", runtime: false},
      {:ezstd, "~> 1.0", runtime: false},
      {:phoenix_bakery, "~> 0.1.0", runtime: false}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["tailwind default", "esbuild default"],
      "assets.deploy": ["tailwind default --minify", "esbuild default --minify", "phx.digest"]
    ]
  end
end
