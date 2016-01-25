alias Nats.Connection

defmodule Sub do
  def receive_loop(pid), do: receive_loop(pid, :infinite)
  def receive_loop(pid, how_many) do
    IO.puts "starting; receiving #{how_many} messages..."
    receive_loop1(pid, how_many)
  end
  defp receive_loop1(_, 0), do: true
  defp receive_loop1(pid, num_left) do
    receive do
      w -> IO.puts("received NATS message: #{inspect(w)}")
      receive_loop1(pid, num_left - 1)
    end
  end
end

subject = "elixir.subject"
subject_pat = ">"
IO.puts "starting NATS nats link..."
{:ok, pid} = Connection.start_link
#IO.puts "starting subscribing to #{subject_pat}..."
#receive do
#  after 300 -> IO.puts "starting up Sub..."
#end
Connection.subscribe(pid, subject_pat);
receive do
  after 300 -> IO.puts "starting up Sub..."
end
Connection.pub(pid, subject, "hello NATS world!")
Sub.receive_loop(pid, 1)
IO.puts "exiting..."
