defmodule Nats.Connection do
  use GenServer

  @default_port 4222
  @conn_timeout 5000
  @start_state %{state: :want_info, sock: nil,
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
#    IO.puts "connecting to NATS...#{inspect(state)}"
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
  def handle_info({:command, cmd}, %{sock: socket} = state) do
    pack = Nats.Parser.encode(cmd)
    case :gen_tcp.send(socket, pack) do  # :ssl.send(socket, pack) do # 
      :ok -> :ok # IO.puts "sent #{inspect(pack)}..."
      {:error, :closed} -> IO.puts "socket closed: ignoring for NOW!!"
      oops -> IO.puts "NATS send unexpected result: #{inspect(oops)}"
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
#    IO.puts ("tcp: #{inspect(data)}")
    val = Nats.Parser.parse(state.ps, data)
#    IO.puts "received NATS message: #{inspect(val)}"
    case val do
      {:ok, msg, rest, nps} -> handle_packet(%{state | ps: nps}, msg)
      other -> nats_err(state,
                        "received a bad parser result: #{inspect(other)}")
    end
  end
  def handle_info({:ssl, _sock, data}, state) do
#    IO.puts ("tcp: #{inspect(data)}")
    val = Nats.Parser.parse(state.ps, data)
#    IO.puts "received NATS message: #{inspect(val)}"
    case val do
      {:ok, msg, rest, nps} -> handle_packet(%{state | ps: nps}, msg)
      other -> nats_err(state,
                        "received a bad parser result: #{inspect(other)}")
    end
  end
  defp handle_packet(state, msg) do
    case msg do
      {:info, json} -> nats_info(state, json)
      {:connect, json} -> nats_connect(state, json)
      {:ping} -> nats_ping(state)
      {:pong} -> nats_pong(state)
      {:ok} -> nats_ok(state)
      {:err, why} -> nats_err(state, why)
      {:msg, sub, sid, rep, what} -> nats_msg(state, sub, sid, rep, what)
      {:pub, sub, rep, what} -> nats_pub(state, sub, rep, what)
      _ -> nats_err(state, "received bad NATS verb: -> #{inspect(msg)}")
    end
  end
  defp nats_err(state, _what) do
#    IO.puts("NATS: err: #{inspect(what)}")
    {:noreply, %{state | state: :error}}
  end
  defp nats_info(state = %{state: :want_info}, json) do
#    IO.puts "NATS: received INFO: #{inspect(json)}"
    connect_json = %{
        "version" => "elixir-alpha",
        "tls_required" => false,
        "verbose" => false
    }
    if json["tls_required"] && false do
      opts = []
      IO.puts "starting SSL handshake:..."
      res = :ssl.connect(state.sock, opts, state.timeout)
      IO.puts "done: #{inspect(res)}"
      {:ok, port} = res
      state = %{state | sock: port}
    end
    connect(self(), connect_json)
    {:noreply, %{state | state: :connected}}
  end
  defp nats_info(state, _json) do
#    IO.puts "NATS: received INFO after handshake: #{inspect(json)}"
    {:noreply, state}
  end
  defp nats_connect(state = %{state: :want_connect}, _json) do
#    IO.puts "NATS: received CONNECT: #{inspect(json)}"
    {:noreply, %{state | state: :connected}}
  end
  defp nats_connect(state, _json) do
#    IO.puts "NATS: received unexpected CONNECT: #{inspect(json)}"
    {:noreply, state}
  end
  defp nats_ping(state) do
#    IO.puts "NATS: received PING"
    pong(self())
    {:noreply, state}
  end
  defp nats_pong(state) do
#    IO.puts "NATS: received PONG"
    {:noreply, state}
  end
  defp nats_ok(state) do
#    IO.puts "NATS: received OK"
    {:noreply,state}
  end
  defp nats_msg(state = %{state: :connected}, _sub, _sid, _ret, _what) do
#    IO.puts "NATS: received MSG #{sub} #{sid} #{ret} #{what}"
    {:noreply, state}
  end
  defp nats_msg(state, _sub, _sid, _ret, _what) do
#    IO.puts "NATS: received MSG before handshake"
    {:noreply, state}
  end
  defp nats_pub(state = %{state: :connected}, _sub, _ret, _what) do
#    IO.puts "NATS: received PUB: #{sub} #{ret} #{what}"
    {:noreply, state}
  end
  defp nats_pub(state, _sub, _ret, _what) do
#    IO.puts "NATS: received PUB before handshake"
    {:noreply, state}
  end
end

