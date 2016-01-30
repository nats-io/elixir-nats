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
    {:ok, _rest} = Client.sub(con, self(), subject)
    # can subscribe twice!
    {:ok, _} = Client.sub(con, self(), subject)

    subject = subject <> subject
    {:ok, ref1} = Client.sub(con, self(), subject, "ret")
    {:ok, ref2} = Client.sub(con, self(), subject, "ret")

    :ok = Client.unsub(con, ref1)
    :ok = Client.unsub(con, ref2)
    
    :ok = Client.pub(con, "subject", "hello world")
    :ok = Client.pub(con, "subject", "return", "hello return world")
  end
end
