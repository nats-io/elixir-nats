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
    :ok = Client.subscribe(con, self(), subject)
    {:error, _} = Client.subscribe(con, self(), subject)

    subject = subject <> subject
    :ok = Client.subscribe(con, self(), subject, "ret")
    {:error, _} = Client.subscribe(con, self(), subject, "ret")

    
    :ok = Client.pub(con, "subject", "hello world")
    :ok = Client.pub(con, "subject", "return", "hello return world")
  end
end
