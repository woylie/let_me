defmodule LetMe.MixProject do
  use Mix.Project

  @source_url "https://github.com/woylie/let_me"
  @version "2.0.0"

  def project do
    [
      app: :let_me,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      dialyzer: [
        plt_file: {:no_warn, ".plts/dialyzer.plt"}
      ],
      name: "LetMe",
      source_url: @source_url,
      homepage_url: @source_url,
      description: description(),
      package: package(),
      docs: docs()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  def cli do
    [
      preferred_envs: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.github": :test,
        precommit: :test
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
      {:castore, "== 1.0.18", only: :test},
      {:credo, "== 1.7.17", only: [:dev, :test], runtime: false},
      {:dialyxir, "1.4.7", only: [:dev, :test], runtime: false},
      {:ex_doc, "0.40.1", only: :dev, runtime: false},
      {:excoveralls, "0.18.5", only: :test},
      {:makeup_diff, "0.1.1", only: :dev, runtime: false}
    ]
  end

  defp description do
    "Authorization library with a DSL and introspection"
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Changelog" => @source_url <> "/blob/main/CHANGELOG.md",
        "Sponsor" => "https://github.com/sponsors/woylie"
      },
      files: ~w(lib .formatter.exs mix.exs README* LICENSE* CHANGELOG*)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["cheatsheets/rules.cheatmd", "README.md", "CHANGELOG.md"],
      source_ref: @version,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      groups_for_extras: [
        Cheatsheets: ~r/cheatsheets\/.?/
      ],
      groups_for_modules: [
        Structs: [
          LetMe.AllOf,
          LetMe.AnyOf,
          LetMe.Check,
          LetMe.Literal,
          LetMe.Not,
          LetMe.Rule
        ]
      ]
    ]
  end

  defp aliases do
    [
      precommit: [
        "compile --warning-as-errors",
        "deps.unlock --unused",
        "format",
        "credo",
        "coveralls"
      ]
    ]
  end
end
