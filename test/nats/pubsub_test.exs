defmodule Nats.PubsubTest do
	use ExUnit.Case, async: true
	alias Nats.Connection

  def receive_loop(pid) do
		IO.puts "starting receive loop..."
		receive_loop(pid, 5)
	end
  def receive_loop(_, 0) do true end
  def receive_loop(pid, inactivityCount) do
		receive do
			w -> IO.puts("received NATS message: #{inspect(w)}")
		after 3_000 ->
			IO.puts "sending ping after 3 seconds of activity..."
			Connection.ping(pid)
			inactivityCount = inactivityCount - 1
		end
		receive_loop(pid, inactivityCount)
	end

	test "Open and test a connection..." do
		subject = ">"
		IO.puts "starting NATS nats link..."
		{:ok, pid} = Connection.start_link
		IO.puts "starting subscribing to #{subject}..."
		Connection.subscribe(pid, subject);
		receive_loop(pid)
		IO.puts "exiting..."
# FIXME: 0.
#		{:ok, _state } = Nats.Connection.start_link
#		receive do w -> IO.puts("got: #{w}") end
	end
end
