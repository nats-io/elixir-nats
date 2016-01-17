defmodule Nats.Connection do
  use GenServer

	@default_port 4222
	@conn_timeout 5000
  @start_state %{sock_state: :handshake, sock: nil,
								 port: @default_port,
								 timeout: @conn_timeout,
								 opts: [:binary, active: true]}
  def start_link do
		start_link @default_port
  end

	def start_link(port) do
    GenServer.start_link(__MODULE__, %{@start_state | port: port})
	end
  def init(state) do
		IO.puts "connecting to NATS...#{inspect(state)}"
    opts = state[:opts]

    {:ok, connected} = :gen_tcp.connect('localhost',
																				state[:port],
																				opts,
																				state[:timeout])
		ns = %{state | sock: connected}
#		{:error, reason} ->
#   {:backoff, B1, state} # inc state.incre
#		connect_json = %{
#			"version" => "elixir-alpha",
#			"tls_required" => false
#		}
#		{:noreply, ns } = handle_info({:command, {:connect, connect_json}}, state)

		:ok = :inet.setopts(connected, opts)
		IO.puts "connected to nats: #{inspect(ns)}"
		{:ok, ns}
  end

	def handle_info({:command, cmd}, %{sock_state: _con_state,
																		 sock: socket} = state) do
		pack = Nats.Parser.encode(cmd)
    :ok = :gen_tcp.send(socket, pack)
		IO.puts("sent #{inspect(pack)}...")
		{:noreply, state}
  end
	def handle_info({:tcp_closed, sock}, state) do
		IO.puts ("tcp_closed: #{inspect(sock)}")
		{ :noreply, state }
	end
	def handle_info({:tcp_error, sock, reason}, state) do
		IO.puts ("tcp_closed: #{inspect(sock)}: #{reason}")
		{ :noreply, state }
	end
	def handle_info({:tcp_passive, sock}, state) do
		IO.puts ("tcp_passive: #{inspect(sock)}")
		{ :noreply, state }
	end
	def handle_info({:tcp, _sock, data}, state) do
		  #%{sock_state: _con_state, sock: _ignore} = state) do
		IO.puts ("tcp: #{inspect(data)}")
		val = Nats.Parser.parse(data)
    IO.puts "received NATS message: #{inspect(val)}"
		connect_json = %{
			"version" => "elixir-alpha",
			"tls_required" => false,
			"verbose" => false
			}
		case val do
			{:ok, msg} -> 
				case msg do
					{:info, _json} -> handle_info({:command, {:connect, connect_json}},
																				state)
					{:ping} -> handle_info({:command, {:pong}}, state)
					{:pong} -> {:noreply, state } # fixme pong handling (timeoutagent)
					{:ok} -> {:noreply, state }
					{:err, why} -> IO.puts("NATS error: #{why}")
					_ -> IO.puts "received bad NATS verb: -> #{inspect(msg)}"
				end
			other -> IO.puts "received something strange: oops -> #{inspect(other)}"
		end
		{:noreply, state}
  end
end
