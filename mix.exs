# Copyright 2016 Apcera Inc. All rights reserved.
defmodule Nats.Mixfile do
  use Mix.Project

  @name "Nats"
  @git_url "https://github.com/nats-io/elixir-nats"
  @nats_io_url "https://nats.io/"
  @home_url @git_url
  @doc_url "https://nats-io.github.com/elixir-nats/"
  @description "NATS framework for Elixir"

  @version "0.1.5"

  def project do
    [app: :nats,
     version: @version,
     elixir: ">= 1.2.0",
     description: @description,
     package: package(),
     source_url: @git_url,
     homepage_url: @home_url,
     deps: deps(),
     name: @name,
     docs: [extra_section: "TOC", main: "readme",
            extras: ["README.md", "EXAMPLES.md"]],
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: ["coveralls": :test, "coveralls.detail":
                         :test, "coveralls.post": :test]]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [{:exrm, "~> 1.0", only: :dev},
     {:excoveralls, "~> 0.5", only: :test},
     {:earmark, "~> 1.0", only: :dev},
     {:ex_doc, "~> 0.12", only: :dev}]
  end

  defp package do
    [
      name: "natsio",
      files: ~w(lib src bench mix.exs LICENSE README.md),
      maintainers: ["camros", "nats.io", "Apcera"],
      licenses: ["MIT"],
      links: %{"GitHub" => @git_url,
               "Docs" => @doc_url,
               "Nats.io" => @nats_io_url}
    ]
  end
end
