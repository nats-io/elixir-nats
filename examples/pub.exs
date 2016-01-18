alias Nats.Connection

defmodule Pub do
  def receive_loop(pid) do
		IO.puts "starting receive loop..."
		receive_loop(pid, 10)
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
end

subject = ">"
IO.puts "starting NATS nats link..."
{:ok, pid} = Connection.start_link
IO.puts "starting subscribing to #{subject}..."
Connection.subscribe(pid, subject);
Pub.receive_loop(pid)
IO.puts "exiting..."
