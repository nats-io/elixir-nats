# Copyright 2016 Apcera Inc. All rights reserved.
defmodule Nats.ConnectionTest do
  use ExUnit.Case, async: true
  alias Nats.Connection

  @tag disabled: true
  test "Open a default connection" do
    opts = %{ tls_required: false,
              auth: %{}, # "user" => "user", "pass" => "pass"},
              verbose: false,
              timeout: 5000,
              host: "127.0.0.1", port: 4222,
              socket_opts: [:binary, active: true],
              ssl_opts: []}
    {:ok, con } = Connection.start_link(self(), opts)
    assert :ok == Connection.ping(con)
    Connection.ping(con)
    Connection.pong(con)
    Connection.ok(con)
    Connection.error(con, "a message")
    {:ok, con } = Connection.start_link(self(), opts)
    assert :ok == Connection.ping(con)
    Connection.subscribe(con, ">")
    Connection.subscribe(con, ">", "sid")
    Connection.subscribe(con, ">", "q", "sid")
    Connection.pub(con, "subject", "hello world")
    Connection.pub(con, "subject", "reply", "hello nats world")
    Connection.msg(con, "subject", "hello world nosid msg")
    Connection.msg(con, "subject", "sid", "hello world msg")
    Connection.msg(con, "subject", "sid" , "reply", "hello nats world msg")
    receive do
      _w -> true # IO.puts("got: #{inspect(_w)}")
    after 1000 -> :ok
    end
  end
end
