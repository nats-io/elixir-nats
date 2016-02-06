# Copyright 2016 Apcera Inc. All rights reserved.
defmodule Nats.ClientTest do
  use ExUnit.Case, async: false
  alias Nats.Client

  @non_tls_port 4222
  @tls_port 4223
  @auth_port 4224
  
  setup_all do
    gnatsd = TestHelper.run_gnatsd
    on_exit fn ->
      TestHelper.stop_gnatsd(gnatsd)
    end
    sec_gnatsd = TestHelper.run_gnatsd("--tls -c " <>
                                       TestHelper.gnatsd_conf_file("tls.conf"))
    on_exit fn ->
      TestHelper.stop_gnatsd(sec_gnatsd)
    end
    sec_gnatsd = TestHelper.run_gnatsd("-c " <>
                                       TestHelper.gnatsd_conf_file("auth.conf"))
    on_exit fn ->
      TestHelper.stop_gnatsd(sec_gnatsd)
    end
  end
  
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
    :ok = GenServer.cast(con, {:write,
                               String.duplicate("+OK\r\n", 20)})
    :ok = Client.flush(con)
    # get coverage...
    :ok = GenServer.cast(con, {:write,
                               String.duplicate("PING\r\n", trunc(32767/5))})
    :ok = Client.flush(con)
    :ok = GenServer.cast(con, {:write, ""})
    :ok = Client.flush(con)
  end

  test "Client vs. server tls_required" do
    opts = %{ tls_required: true, port: @non_tls_port, }
    {:error, _why } = Client.start opts
    opts = %{ tls_required: true, port: @tls_port, }
    {:ok, conn} = Client.start opts
    GenServer.stop(conn)
  end
  test "Client vs. server auth" do
    # see if the server wants auth, it should NOT and we do... so we should fail
    opts = %{ auth: %{ "user" => "user", "pass" => "pass"}, }
    {:error, _why } = Client.start opts
    # connect to the other server, we want auth and they have it so this
    # should succeed
    opts = %{ port: @auth_port, auth: %{ "user" => "user", "pass" => "pass"}}
    {:ok, conn } = Client.start opts
    GenServer.stop(conn)
    # reverse of the above, connect with no auth and see if we get an error
    # back...
    opts = %{ port: @auth_port }
    {:error, _why} = Client.start opts
    
    # We should fail if we pass invalid credentials, make sure...
    opts = %{ port: @auth_port, auth: %{ "user" => "oops", "pass" => "oops22"}}
    {:ok, conn} = Client.start opts
    ## FIXME: jam, handshake failure...
    :ok = Client.pub(conn, "fail", "mesg")
  end
end
