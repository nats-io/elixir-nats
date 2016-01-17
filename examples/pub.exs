defmodule Pub do
  def receive_loop(pid) do
		receive do
			w -> IO.puts("receive: got: #{inspect(w)}")
		after 3_000 ->
			IO.puts "sending ping after 3 seconds..."
			send pid, {:command, {:ping}}
		end
		receive_loop(pid)
	end
end

alias Nats.Connection

{:ok, pid} = Connection.start_link
send pid, {:command, {:sub, ">", nil, "0"}}
Pub.receive_loop(pid)
