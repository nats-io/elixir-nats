# Copyright 2016 Apcera Inc. All rights reserved.
defmodule Nats.PubsubTest do
  use ExUnit.Case, async: false
  alias Nats.Client

  def receive_loop(pid, acc) do
    receive do
      _w -> receive_loop(pid, acc + 1)
    after 100 ->
      acc
    end
  end

  @tag disabled: true
  test "Publish some messages..." do
    subject = "TheSubject"
    {:ok, con} = Client.start_link
    :ok = Client.subscribe(con, self(), subject)
    :ok = Client.subscribe(con, self(), ">")
    Client.pub(con, subject, "1: hello")
    Client.pub(con, subject, "2: NATS")
    Client.pub(con, subject, "3: world")
    Client.pub(con, subject <> subject, "4: 4")
    Client.pub(con, subject <> subject, "5: 5")
    Client.pub(con, subject <> subject, "6: 6")
    # 6 messages + the three we match twice on our wildcard
    assert 9 == receive_loop(con, 0)
#    Client.unsub(con, sub_subject)
  end
end
