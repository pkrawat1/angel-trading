defmodule AngelTrading.MixProject do
  use Mix.Project

  def project do
    [
      app: :angel_trading,
      version: "0.1.0",
      elixir: "~> 1.17.2",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      elixirc_options: [warnings_as_errors: true]
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
      {:phoenix, "~> 1.7.14"},
      {:phoenix_html, "~> 4.1.1"},
      {:phoenix_ecto, "~> 4.6"},
      {:phoenix_live_reload, "~> 1.5.3", only: :dev},
      {:phoenix_live_view, "~> 0.20.17"},
      {:floki, ">= 0.36.2", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.4"},
      {:esbuild, "~> 0.8.1", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.3", runtime: Mix.env() == :dev},
      {:swoosh, "~> 1.16.10"},
      {:finch, "~> 0.18"},
      {:telemetry_metrics, "~> 1.0.0"},
      {:telemetry_poller, "~> 1.1.0"},
      {:gettext, "~> 0.24"},
      {:jason, "~> 1.4.4"},
      {:tesla, "~> 1.11.2"},
      {:bandit, "~> 1.5.5"},
      {:number, "~> 1.0.5"},
      {:timex, "~> 3.7.11"},
      {:trade_galleon, git: "https://github.com/pkrawat1/trade_galleon.git", branch: "master"},
      # {:trade_galleon, path: "../trade_galleon"},
      {:mix_test_watch, "~> 1.2.0", only: [:dev, :test], runtime: false},
      {:rustler, "~> 0.34.0", runtime: false},
      {:brotli, ">= 0.3.2", runtime: false},
      {:ezstd, "~> 1.1.0", runtime: false},
      {:phoenix_bakery, "~> 0.1.2", runtime: false},
      {:explorer, "~> 0.9.0"},
      {:cachex, "~> 3.6"},
      {:langchain, "~> 0.3.0-rc.0"},
      {:earmark, "~> 1.4.47"},
      {:mock, "~> 0.3.8", only: :test}
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
      "assets.deploy": ["tailwind default --minify", "esbuild default", "phx.digest"]
    ]
  end
end
