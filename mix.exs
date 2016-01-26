# Copyright 2016 Apcera Inc. All rights reserved.
defmodule Nats.Mixfile do
  use Mix.Project

  @name "Nats"
  @git_url "https://github.com/nats-io/elixir-nats"
  @home_url @git_url
  @description "NATS framework for Elixir"
  
  @version "0.1.3"

  def project do
    [app: :nats,
     version: @version,
     elixir: "~> 1.2",
     description: @description,
     package: package,
     source_url: @git_url,
     homepage_url: @home_url,
     deps: deps,
     name: @name,
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: ["coveralls": :test, "coveralls.detail":
                         :test, "coveralls.post": :test],
     docs: []]
    # main: "README", extras: ["README.md"]]]
#            #source_ref: "v#{@version}",
#            source_url: "./"]]
  end


  def application do
    [applications: [:logger]]
  end

  # Dependencies
  defp deps do
    [{:exrm, "~> 0.18.8"},
     {:excoveralls, "~> 0.4.5", only: :test},
     {:benchfella, "~> 0.3.1", only: :dev},
     {:earmark, "~> 0.2.1", only: :dev},
     {:ex_doc, "~> 0.11.4", only: :dev}]
  end

  defp package do
    [maintainers: ["nats-io", "Apcera"],
     licenses: ["MIT"],
     links: %{"GitHub" => @git_url,
              "nats.io" => "https://nats.io/"},
     files: ~w(lib src/*.xrl src/*.yrl mix.exs *.md LICENSE)]
  end
end
