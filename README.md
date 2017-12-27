# An Elixir framework for [NATS](https://nats.io/)
[![Build Status](https://travis-ci.org/nats-io/elixir-nats.svg?branch=master)](https://travis-ci.org/nats-io/elixir-nats)
[![Coverage Status](https://coveralls.io/repos/github/nats-io/elixir-nats/badge.svg?branch=master)](https://coveralls.io/github/nats-io/elixir-nats?branch=master)

_Elixir style_ documentation is located [here](https://nats-io.github.io/elixir-nats/)

## Getting Started

The framework requires Elixir 1.2.2 or above. To use it in your project,
add the following to your `mix.exs`:

```elixir
defp deps do
    # for github
    [{:nats, git: "https://github.com/nats-io/elixir-nats.git"}]
    # for hex (forthcoming)
    [{:natsio, "~> 0.1.6"}]
end
```


## To build and/or test from sources

Run the test servers:

```sh
./test/run-test-servers.sh
```

Clone, fork or pull this repository. And then:

```sh
$ mix deps.get
$ mix compile
$ mix test
```

To run the examples:

```sh
$ mix run examples/sub.exs
$ mix run examples/pub.exs
```

The default NATS configuration looks for a [gnatsd](https://github.com/nats-io/gnatsd) instance running on the default port of 4222 on 127.0.0.1.

You can override the configuration by passing a map to `Client.start_link`. For example:

```elixir
  alias Nats.Client
  
  nats_conf = %{host: "some-host", port: 3222,
                tls_required: true,
                auth: %{ user: "some-user", pass: "some-pass"}}
  {:ok, ref} = Client.start_link(nats_conf)
  Client.pub(ref, "subject", "hello NATS world!")
```

The framework leverages the standard logger, by default only errors are logged. To view additional logging, update your `config/config.exs`:
```elixir
use Mix.Config

# debug will log most everything
# info prints connection lifecycle events
# error prints errors
config :logger, level: :debug
```

## Status

Most NATS related capabilities are in place: publishing, subscribing, tls,
authorization.

Elixir Application, supervisor/monitor and environment support needs improved

Documentation is minimal. For now:

```sh
$ mix docs
$ open docs/index.html
$ cat examples/*.exs
```

## Release Library

Bump version in `mix.exs`:

```elixir
  ...

  @version "0.1.6"

  ...
``` 

As an administrator in the natsio [hex package](https://hex.pm/packages/natsio):

```sh
mix hex.publish
```

## License

[License](LICENSE)

Copyright 2016 Apcera Inc. All rights reserved. 
