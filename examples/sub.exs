# Copyright 2016 Apcera Inc. All rights reserved.
alias Nats.Client

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
      continue(pid, num_left)
    end
  end
  defp continue(pid, :infinite), do: receive_loop1(pid, :infinite)
  defp continue(pid, num), do: receive_loop1(pid, num - 1)
end

subject_pat = ">"
IO.puts "starting NATS nats link..."
{:ok, pid} = Client.start_link
receive do after 500 -> true end
IO.puts "subscribing..."
ref = Client.sub(pid, self(), subject_pat);
Sub.receive_loop(pid)
Client.unsub(pid, ref)
IO.puts "exiting..."
