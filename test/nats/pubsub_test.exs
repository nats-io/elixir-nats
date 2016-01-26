defmodule Nats.PubsubTest do
  use ExUnit.Case, async: true
  alias Nats.Client

  def receive_loop(pid) do
    receive_loop(pid, 5)
  end
  def receive_loop(_, 0) do true end
  def receive_loop(pid, inactivityCount) do
    receive do
      _w ->
        # IO.puts("received NATS message: #{inspect(_w)}")
        true
    after 3_000 ->
        inactivityCount = inactivityCount - 1
    end
    receive_loop(pid, inactivityCount)
  end

  @tag disabled: true
  test "Open and test a connection..." do
    subject = ">"
    {:ok, pid} = Client.start_link
    Client.subscribe(pid, subject);
    receive_loop(pid)
  end
end
