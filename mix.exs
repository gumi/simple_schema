defmodule SimpleSchema.Mixfile do
  use Mix.Project

  def project do
    [
      app: :simple_schema,
      version: "1.2.1",
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      description: "Validate JSON and store to a specified data structure",
      package: [
        maintainers: ["melpon", "kenichirow"],
        licenses: ["Apache 2.0"],
        links: %{"GitHub" => "https://github.com/gumi/simple_schema"}
      ],
      docs: [main: "SimpleSchema"],
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      source_url: "https://github.com/gumi/simple_schema"
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
      {:ex_json_schema, "~> 0.9"},
      {:ex_doc, "~> 0.28", only: :dev, runtime: false},
      {:memoize, "~> 1.4"}
    ]
  end
end
