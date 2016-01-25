alias Nats.Connection

defmodule Pub do
  def pub_loop(pid, sub, msg, count) do
    IO.puts "starting: publishing #{count} messages..."
    pub_loop1(pid, sub, msg, count)
  end
  def pub_loop1(_, _, _, 0) do true end
  def pub_loop1(pid, sub, msg, count) do
    pub_loop1(pid, sub, msg, count - 1)
    Connection.pub(pid, sub, "#{count}: #{msg}")
  end
end

subject = "elixir.subject"
msg = "hello NATS world"
IO.puts "starting NATS nats link..."
{:ok, pid} = Connection.start_link
receive do after 500 -> true end
Pub.pub_loop(pid, subject, msg, 10)
IO.puts "exiting..."
