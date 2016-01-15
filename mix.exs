defmodule Nats.Mixfile do
  use Mix.Project

	@git_url "https://github.com/nats-io/nats-elixir"
  @version "0.1.1"

  def project do
    [app: :nats,
     version: @version,
     elixir: "~> 1.2",
     name: "nats",
     source_url: @git_url,
     homepage_url: @git_url,
     deps: deps,
     package: package,
     description: "NATS framework for Elixir",

		 test_coverage: [tool: ExCoveralls],
     preferred_cli_env: ["coveralls": :test, "coveralls.detail":
												 :test, "coveralls.post": :test],
     docs: [readme: "README.md", main: "README",
            source_ref: "v#{@version}", source_url: @git_url]]
  end


  def application do
    [applications: [:logger]]
  end

  # Dependencies
  defp deps do
    [{:excoveralls, "~> 0.4", only: :test},
     {:benchfella, "~> 0.3.0", only: :dev},
     {:earmark, "~> 0.1", only: :dev},
     {:ex_doc, "~> 0.7", only: :dev}]
  end

  defp package do
    [maintainers: ["nats-io", "Apcera"],
     licenses: ["MIT"],
     links: %{"GitHub" => @git_url,
						  "Nats.io" => "https://nats.io/"}]
  end
end
