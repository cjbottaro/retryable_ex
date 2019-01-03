defmodule Retryable.MixProject do
  use Mix.Project

  def project do
    [
      app: :retryable_ex,
      version: "2.0.0",
      elixir: ">= 1.4.0",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env),
      docs: [
        main: "Retryable",
        extras: [
          "README.md": [title: "README"],
          "CHANGELOG.md": [title: "CHANGELOG"],
        ],
      ],
      description: "Simple code retrying without metaprogramming.",
      package: [
        licenses: ["Apache 2"],
        maintainers: ["Christopher J. Bottaro"],
        links: %{"GitHub" => "https://github.com/cjbottaro/retryable_ex"}
      ]
    ]
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
      {:mox, "~> 0.3", only: :test},
      {:ex_doc, "~> 0.19", only: :dev},
    ]
  end

  defp elixirc_paths(:test) do
    ["lib", "test/support"]
  end

  defp elixirc_paths(_) do
    ["lib"]
  end
end
