# Copyright 2016 Apcera Inc. All rights reserved.
defmodule Nats.ClientTest do
  use ExUnit.Case, async: false
  alias Nats.Client

  @tag disabled: true
  test "Open a default client" do
    subject = "FOO-bar"

    {:error, _rest} = Client.start(%{host: ''})

    {:error, _rest} = Client.start(%{timeout: 0})
    
    {:ok, con } = Client.start_link
    {:ok, ref1} = Client.sub(con, self(), subject)

    {:error, _} = Client.unsub(con, {elem(ref1, 0), spawn(fn -> 1 + 1 end)})

    # can subscribe twice!
    {:ok, ref2} = Client.sub(con, self(), subject)
    assert :ok == Client.unsub(con, ref1)
    assert :ok == Client.unsub(con, ref2)
    {:error, _} = Client.unsub(con, ref2)
    subject = subject <> subject
    {:ok, ref1} = Client.sub(con, self(), subject, "ret")
    {:ok, ref2} = Client.sub(con, self(), subject, "ret")

    :ok = Client.unsub(con, ref1)
    :ok = Client.unsub(con, ref2)
    {:error, _} = Client.unsub(con, ref2)
    
    :ok = Client.pub(con, "subject", "hello world")
    :ok = Client.pub(con, "subject", "return", "hello return world")

    :ok = Client.flush(con)
    :ok = GenServer.call(con, {:cmd,
                               String.duplicate("+OK\r\n", 20),
                               false})
    :ok = Client.flush(con)
    # get coverage...
    :ok = GenServer.call(con, {:cmd,
                               String.duplicate("PING\r\n", trunc(32767/5)),
                               false})
    :ok = Client.flush(con)
    :ok = GenServer.call(con, {:cmd, nil, true})
    :ok = Client.flush(con)
  end

  test "Client vs. server tls_required" do
    opts = %{ tls_required: true, port: TestHelper.default_port, }
    {:error, _why } = Client.start opts
    opts = %{ tls_required: true, port: TestHelper.tls_port, }
    {:ok, conn} = Client.start opts
    GenServer.stop(conn)
  end
  test "Client vs. server auth" do
    # see if the server wants auth, it should NOT and we do... so we should fail
    opts = %{ auth: %{ "user" => "user", "pass" => "pass"}, }
    {:error, _why } = Client.start opts
    # connect to the other server, we want auth and they have it so this
    # should succeed
    opts = %{ port: TestHelper.auth_port,
              auth: %{ "user" => "user", "pass" => "pass"}}
    {:ok, _conn } = Client.start opts
    #GenServer.stop(_conn)
    # reverse of the above, connect with no auth and see if we get an error
    # back...
    opts = %{ port: TestHelper.auth_port}
    {:error, _why} = Client.start opts
    
    # We should fail if we pass invalid credentials, make sure...
    opts = %{ port: TestHelper.auth_port,
              auth: %{ "user" => "oops", "pass" => "oops22"}}
    {:error, _what} = Client.start opts
  end
end
