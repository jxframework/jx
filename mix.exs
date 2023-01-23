defmodule Jx.MixProject do
  use Mix.Project

  @source_url "https://github.com/jxframework/jx"
  @version "0.1.0"

  def project do
    [
      app: :jx,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      name: "Jx",
      description: "Pattern matching with binding of functions to variables for Elixir",
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ex_doc, "~> 0.29.0", only: :docs}
    ]
  end

  defp package do
    [
      maintainers: ["Chris Kwiatkowski"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "Jx",
      extras: [
        "CHANGELOG.md"
      ],
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"]
    ]
  end
end