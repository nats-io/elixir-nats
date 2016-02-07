# Copyright 2016 Apcera Inc. All rights reserved.
defmodule Nats.PubsubTest do
  use ExUnit.Case, async: false
  alias Nats.Client

  def receive_loop(pid, acc) do
    receive do
      _w -> receive_loop(pid, acc + 1)
    after 200 ->
      acc
    end
  end

  @tag disabled: true
  test "Publish some messages..." do
    subject = "TheSubject"
    {:ok, con} = Client.start_link
    {:ok, ref1} = Client.sub(con, self(), subject)
    {:ok, ref2} = Client.sub(con, self(), ">")
    Client.pub(con, subject, "1: hello")
    Client.pub(con, subject, "2: NATS")
    Client.pub(con, subject, "3: world")
    Client.pub(con, subject <> subject, "4: 4")
    Client.pub(con, subject <> subject, "5: 5")
    Client.pub(con, subject <> subject, "6: 6")
    # 6 messages + the three we match twice on our wildcard
    assert 9 == receive_loop(con, 0)
    :ok = Client.unsub(con, ref1)
    {:error, _rest} = Client.unsub(con, ref1)
    :ok = Client.unsub(con, ref2)
    {:error, _rest} = Client.unsub(con, ref2)
  end
end
