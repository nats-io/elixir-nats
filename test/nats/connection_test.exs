# Copyright 2016 Apcera Inc. All rights reserved.
defmodule Nats.ConnectionTest do
  use ExUnit.Case, async: false
  alias Nats.Connection

  @tag disabled: true
  test "Open a default connection" do
    :erlang.process_flag(:trap_exit, true)
    opts = %{ tls_required: false,
              auth: %{}, # "user" => "user", "pass" => "pass"},
              verbose: false,
              timeout: 5000,
              host: "127.0.0.1", port: TestHelper.default_port,
              socket_opts: [:binary, active: :once],
              ssl_opts: []}
    {:ok, con } = Connection.start_link(self(), opts)
    GenServer.stop(con)
    # reopen...
    {:ok, _con } = Connection.start_link(self(), opts)
  end
end
