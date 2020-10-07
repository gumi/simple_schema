defmodule SimpleSchema.Mixfile do
  use Mix.Project

  @source_url "https://github.com/gumi/simple_schema"
  @version "1.2.0"
  @name "SimpleSchema"

  def project do
    [
      app: :simple_schema,
      name: @name,
      version: @version,
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "Validate JSON and store to a specified data structure",
      start_permanent: Mix.env() == :prod,
      package: package(),
      docs: docs(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ex_json_schema, "~> 0.7"},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},
      {:memoize, "~> 1.3"}
    ]
  end

  defp package do
    [
      maintainers: ["melpon", "kenichirow"],
      licenses: ["Apache 2.0"],
      links: %{
        "Changelog" => "#{@source_url}/blob/master/CHANGELOG.md",
        "GitHub" => @source_url
      }
    ]
  end

  defp docs do
    [
      main: @name,
      source_ref: @version,
      source_url: @source_url
    ]
  end
end
