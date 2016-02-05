# Copyright 2016 Apcera Inc. All rights reserved.
alias Nats.Client

defmodule Pub do
  def pub(con, sub, msg, tot) do
    IO.puts "starting: publishing #{tot} messages..."
    pub(con, sub, msg, 0, tot)
  end
  def pub(con, _, _, tot, tot) do
    IO.puts "flushing..."
    res = Client.flush(con, :infinity)
    IO.puts "done flushing: #{res}"
    res
  end

  def pub(con, sub, msg, sofar, tot) do
    sofar = sofar + 1
    Client.pub(con, sub, "#{sofar}: #{msg}")
    pub(con, sub, msg, sofar, tot)
  end
end

subject = "elixir.subject"
msg = "hello NATS world"
IO.puts "starting NATS nats link..."
{:ok, pid} = Client.start_link
Pub.pub(pid, subject, msg, 10000)
IO.puts "exiting..."
