defmodule Nats.Connection do
  use GenServer

  @start_state %{sock_state: :handshake, sock: nil}

  def start_link do
    GenServer.start_link(__MODULE__, @start_state)
  end

  def init(state) do
		port = 4222
		IO.puts "connecting to...#{port}"
    opts = [:binary, active: true]

    {:ok, connected} = :gen_tcp.connect('localhost', port, opts)
#		{:error, reason} ->
#   {:backoff, B1, state} # inc state.incre
		IO.puts "connected!"
		IO.puts "sending INFO..."
		info_json = %{
			"version" => "elixir-alpha",
			"tls_required" => false
			}
		_val = handle_call({:command, {:info, info_json}}, self(), state)
    {:ok, %{state | sock: connected}}
  end

	def handle_call({:command, cmd}, _from, %{sock_state: _con_state,
																						sock: socket} = state) do
		pack = Nats.Parser.to_list(cmd)
    :ok = :gen_tcp.send(socket, pack)
		{:noreply, state}
  end

	def handle_call({:tcp, socket, cmd}, _from, %{sock_state: _con_state,
																								sock: socket} = state) do
		val = Nats.Parser.parse(cmd)
		case val do
			{:ok, what} -> IO.puts inspect(what)
			other -> IO.puts "oops -> #{inspect(other)}"
		end
		{:noreply, state}
  end
	
end
