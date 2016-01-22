defmodule Nats.ConnectionTest do
	use ExUnit.Case, async: true
	alias Nats.Connection
	
	test "Open a default connection" do
		# {:ok, con } = Connection.start_link
		# assert :ok == Connection.ping(con)
		# Connection.ping(con)
		# Connection.pong(con)
		# Connection.ok(con)
		# Connection.error(con, "a message")
		# {:ok, con } = Connection.start_link
		# assert :ok == Connection.ping(con)
		# Connection.subscribe(con, ">")
		# Connection.subscribe(con, ">", "sid")
		# Connection.subscribe(con, ">", "q", "sid")
		# Connection.pub(con, "subject", "hello world")
		# Connection.pub(con, "subject", "reply", "hello nats world")
		# Connection.msg(con, "subject", "hello world nosid msg")
		# Connection.msg(con, "subject", "sid", "hello world msg")
		# Connection.msg(con, "subject", "sid" , "reply", "hello nats world msg")
		# receive do w -> IO.puts("got: #{w}") after 500 -> :ok end
	end
end
