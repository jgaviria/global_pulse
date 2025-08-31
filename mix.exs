defmodule GlobalPulse.MixProject do
  use Mix.Project

  def project do
    [
      app: :global_pulse,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {GlobalPulse.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:phoenix, "~> 1.7.0"},
      {:phoenix_html, "~> 3.3"},
      {:phoenix_live_view, "~> 0.19.0"},
      {:phoenix_live_dashboard, "~> 0.8.0"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:esbuild, "~> 0.7", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.2.0", runtime: Mix.env() == :dev},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:plug_cowboy, "~> 2.5"},
      {:httpoison, "~> 2.0"},
      {:websockex, "~> 0.4.3"},
      {:timex, "~> 3.7"},
      {:decimal, "~> 2.0"},
      {:nx, "~> 0.6"},
      {:axon, "~> 0.6"},
      {:explorer, "~> 0.7"},
      {:ecto, "~> 3.10"},
      {:ecto_sql, "~> 3.10"},
      {:phoenix_ecto, "~> 4.4"},
      {:postgrex, ">= 0.0.0"},
      {:floki, "~> 0.34.0"},
      {:tesla, "~> 1.7"},
      {:hackney, "~> 1.18"},
      {:gen_stage, "~> 1.2"},
      {:flow, "~> 1.2"},
      {:cachex, "~> 3.6"}
    ]
  end
end
