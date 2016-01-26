# An Elixir framework for [NATS](https://nats.io/)
[![Build Status](https://travis-ci.com/nats-io/elixir-nats.svg?token=1fr9zyyTUsvtF9yMNgaJ&branch=master)](https://travis-ci.com/nats-io/elixir-nats)
[![Coverage Status](https://coveralls.io/repos/nats-io/elixir-nats/badge.svg?branch=master&service=github)](https://coveralls.io/github/nats-io/elixir-nats?branch=master)

_Elixir style_ documentation is located [here](doc/index.html)

## Getting Started

Install Elixir

Clone, fork or pull this repository. And then, to use (in your `mix.exs`):
```elixir
defp deps do
    [{:nats, "~> 0.1.1"}]
end
```
To build and test from source:

```sh
$ mix deps.get
$ mix compile
$ mix test --cover
```

If that succeeds, then you can run the examples (ensure _gnatsd_ is started on port 4222):

```sh
$ mix run examples/sub.exs
$ mix run examples/pub.exs
$ mix bench --duration 30
```

## TODO

Application, environment configuration in examples. Monitor/supervisor integration.

Documentation, for now:
```sh
$ mix docs
$ open docs/index.html
$ cat examples/*.exs # ;-)
```

Coveralls integration/cleanup

Cleanup and profiling (very little done). This code was put together quickly to get it running.

## [License](LICENSE)

Copyright 2016 Apcera Inc. All rights reserved. 
