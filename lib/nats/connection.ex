defmodule Nats.Connection do
  use GenServer

  @default_port 4222
  @conn_timeout 5000
  @start_state %{sock_state: :handshake, sock: nil,
                 port: @default_port,
                 ps: nil,
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
    {:ok, connected} = :gen_tcp.connect('localhost', state[:port],
                                        opts, state[:timeout])
    ns = %{state | sock: connected}
    :ok = :inet.setopts(connected, opts)
#    IO.puts "connected to nats: #{inspect(ns)}"
    {:ok, ns}
  end

  def ping(self) do send self, {:command, {:ping}}; :ok  end
  def pong(self) do send self, {:command, {:pong}}; :ok end
  def ok(self) do send self, {:command, {:ok}}; :ok end
  def info(self, map) do send self, {:command, {:info, map}}; :ok end
  def connect(self, map) do send self, {:command, {:connect, map}}; :ok end
  def error(self, msg) do send self, {:command, {:err, msg}} end
  def subscribe(self, subject) do subscribe(self, subject, nil, subject) end
  def subscribe(self, subject, sid) do subscribe(self, subject, nil, sid) end
  def subscribe(self, subject, queue, sid) do
    send self, {:command, {:sub, subject, queue, sid}}
  end
  def pub(self, subject, what) do pub(self, subject, nil, what) end
  def pub(self, subject, reply, what) do
    send self, {:command, {:pub, subject, reply, what}}
  end
  def msg(self, subject, what) do msg(self, subject, subject, what) end
  def msg(self, subject, sid, what) do msg(self, subject, sid, nil, what) end
  def msg(self, subject, sid, reply_queue, what) do
    send self, {:command, {:msg, subject, sid, reply_queue, what}}
  end
  def handle_info({:command, cmd}, %{sock_state: _con_state,
                                     sock: socket} = state) do
    pack = Nats.Parser.encode(cmd)
    case :gen_tcp.send(socket, pack) do
      :ok -> IO.puts "sent #{inspect(pack)}..."
      oops -> IO.puts "socket closed: #{inspect(oops)}: ignoring for NOW!!!"
    end
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
    # %{sock_state: _con_state, sock: _ignore} = state) do
    IO.puts ("tcp: #{inspect(data)}")
    val = Nats.Parser.parse(state.ps, data)
    IO.puts "received NATS message: #{inspect(val)}"
    connect_json = %{
        "version" => "elixir-alpha",
        "tls_required" => false,
        "verbose" => false
    }
    case val do
      {:ok, msg, _rest, _ps} ->
        case msg do
          {:info, _json} -> connect(self(), connect_json)
          {:ping} -> pong(self())
          {:pong} -> {:noreply, state }
          {:ok} -> {:noreply, state }
          {:err, why} -> IO.puts("NATS error: #{why}")
          {:msg, _sub, _sid, _rep, _what} -> {:noreply, state }
          {:pub, _sub, _rep, _what} -> {:noreply, state }
          _ -> IO.puts "received bad NATS verb: -> #{inspect(msg)}"
        end
      other -> IO.puts "received something strange: oops -> #{inspect(other)}"
    end
    {:noreply, state}
  end
end
