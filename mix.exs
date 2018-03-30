defmodule Phoenix.ApiVersions.MixProject do
  use Mix.Project

  def project do
    [
      app: :phoenix_api_versions,
      name: "Phoenix API Versions",
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      description: description(),
      deps: deps(),
      package: package(),
      source_url: "https://github.com/smartrent/phoenix_api_versions"
    ]
  end

  defp package do
    [
      maintainers: ["Paul Statezny"],
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/smartrent/phoenix_api_versions"},
      files: ~w(lib mix.exs README.md LICENSE.md)
    ]
  end

  defp description do
    """
    Support multiple versions of a JSON API application in Phoenix, while minimizing maintenance overhead
    """
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:plug, "~> 1.0"},
      {:phoenix, "~> 1.0"},
      {:ex_doc, ">= 0.0.0", only: :dev}
    ]
  end
end
