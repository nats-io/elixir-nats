# An Elixir framework for [NATS](https://nats.io/)
[![Build Status](https://travis-ci.org/nats-io/elixir-nats.svg?branch=master)](https://travis-ci.org/nats-io/elixir-nats)
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

## Status

Most NATS related capabilities are in place: publishing, subscribing, tls,
authorization.

Elixir Application, supervisor/monitor and environment support needs improved

Documentation is minimal. For now:
```sh
$ mix docs
$ open docs/index.html
$ cat examples/*.exs # ;-)
```

## [License](LICENSE)

Copyright 2016 Apcera Inc. All rights reserved. 

