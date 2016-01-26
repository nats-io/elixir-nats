# Copyright 2016 Apcera Inc. All rights reserved.
alias Nats.Client

defmodule Pub do
  def pub_loop(pid, sub, msg, count) do
    IO.puts "starting: publishing #{count} messages..."
    pub_loop1(pid, sub, msg, count)
  end
  def pub_loop1(_, _, _, 0) do true end
  def pub_loop1(pid, sub, msg, count) do
    pub_loop1(pid, sub, msg, count - 1)
    Client.pub(pid, sub, "#{count}: #{msg}")
  end
end

subject = "elixir.subject"
msg = "hello NATS world"
IO.puts "starting NATS nats link..."
{:ok, pid} = Client.start_link
Pub.pub_loop(pid, subject, msg, 10)
receive do after 200 -> true end
IO.puts "exiting..."
