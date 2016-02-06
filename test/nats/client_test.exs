# Copyright 2016 Apcera Inc. All rights reserved.
defmodule Nats.ClientTest do
  use ExUnit.Case, async: false
  alias Nats.Client

  setup_all do
    gnatsd = TestHelper.run_gnatsd
    on_exit fn ->
      TestHelper.stop_gnatsd(gnatsd)
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
  end
end
