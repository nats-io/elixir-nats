# Copyright 2016 Apcera Inc. All rights reserved.
defmodule Nats.ConnectionTest do
  use ExUnit.Case, async: false
  alias Nats.Connection

  test "test general functions" do
  end

  @tag disabled: true
  test "Open a default connection" do
    :erlang.process_flag(:trap_exit, true)
    opts = %{ tls_required: false,
              auth: %{}, # "user" => "user", "pass" => "pass"},
              verbose: false,
              timeout: 5000,
              host: "127.0.0.1", port: 4222,
              socket_opts: [:binary, active: true],
              ssl_opts: []}
    {:ok, con } = Connection.start_link(self(), opts)
    assert :ok == Connection.ping(con)
    assert :ok == Connection.ping(con)
    assert :ok == Connection.pong(con)
    assert :ok == Connection.ok(con)

    assert :ok == Connection.info(con, %{})
    # reopen...
    {:ok, con } = Connection.start_link(self(), opts)
    
    assert :ok == Connection.connect(con, %{})
    # reopen...
    {:ok, con } = Connection.start_link(self(), opts)
    assert :ok == Connection.error(con, "a message")
    # reopen...
    {:ok, con } = Connection.start_link(self(), opts)
    
    assert :ok == Connection.ping(con)
    assert :ok == Connection.sub(con, ">")
    assert :ok == Connection.sub(con, ">", "sid")
    assert :ok == Connection.sub(con, ">", "q", "sid")
    assert :ok == Connection.pub(con, "subject", "hello world")
    assert :ok == Connection.pub(con, "subject", "reply", "hello nats world")

    assert :ok == Connection.msg(con, "subject", "hello world nosid msg")
    # reopen...
    {:ok, con } = Connection.start_link(self(), opts)
    Connection.msg(con, "subject", "sid", "hello world msg")
    # reopen...
    {:ok, con } = Connection.start_link(self(), opts)
    assert :ok == Connection.msg(con, "subject", "sid" , "reply",
                                 "hello nats world msg")
  end
end
