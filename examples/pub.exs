# Copyright 2016 Apcera Inc. All rights reserved.
alias Nats.Client

defmodule Pub do
  def pub(con, subject, msg, tot) do
    IO.puts "publishing #{tot} messages..."
    pub(con, subject, msg, 0, tot)
  end
  def pub(_, _, _, tot, tot), do: true
  def pub(con, subject, msg, sofar, tot) do
    sofar = sofar + 1
    Client.pub(con, subject, "#{sofar}: #{msg}")
    pub(con, subject, msg, sofar, tot)
  end
end

subject = "elixir.subject"
msg = "hello NATS world"
IO.puts "starting NATS..."
{:ok, pid} = Client.start_link
Pub.pub(pid, subject, msg, 10)
GenServer.stop(pid)
IO.puts "exiting..."
