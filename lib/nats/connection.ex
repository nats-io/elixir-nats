defmodule Nats.Connection do
  use GenServer

  @default_host '127.0.0.1'
  @default_port 4222
  @default_timeout 5000
  
  @start_state %{state: :want_info,
                 sock: nil,
                 opts: %{tls_required: false, auth: nil,
                         verbose: false,
                         timeout: @default_timeout,
                         host: @default_host, port: @default_port,
                         socket_opts: [:binary, active: true]},
                 ps: nil}
  def start_link do start_link(@default_host, @default_port) end
  def start_link(host, port \\ @default_port) do
    state = @start_state
    state = %{state | opts: %{state.opts | host: host, port: port}}
    GenServer.start_link(__MODULE__, state)
  end
  def init(state) do
    IO.puts "connecting to NATS...#{inspect(state)}"
    {:ok, connected} = :gen_tcp.connect(state.opts.host,
                                        state.opts.port,
                                        state.opts.socket_opts,
                                        state.opts.timeout)
    ns = %{state | sock: connected}
    # FIXME: jam: required?
    :ok = :inet.setopts(connected, state.opts.socket_opts)
    IO.puts "connected to nats: #{inspect(ns)}"
    {:ok, ns}
  end

  def ping(self) do send self, {:command, {:ping}}; :ok end
  def pong(self) do send self, {:command, {:pong}}; :ok end
  def ok(self) do send self, {:command, {:ok}}; :ok end
  def info(self, map) do send self, {:command, {:info, map}}; :ok end
  def connect(self, map) do send self, {:command, {:connect, map}}; :ok end
  def error(self, msg) do send self, {:command, {:err, msg}}; :ok end
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
  def handle_info({:command, cmd}, state) do
    pack = Nats.Parser.encode(cmd)
    case :gen_tcp.send(state.sock, pack) do
      # case :ssl.send(state.socket, pack) do
      :ok -> :ok # IO.puts "sent #{inspect(pack)}..."
      {:error, :closed} -> IO.puts "socket closed: ignoring for NOW!!"
      oops -> IO.puts "NATS send unexpected result: #{inspect(oops)}"
    end
    {:noreply, state}
  end
  def handle_info({:tcp_closed, _sock}, state) do { :noreply, state } end
  def handle_info({:tcp_error, _sock, _reason}, state) do
    { :noreply, state }
  end
  def handle_info({:tcp_passive, _sock}, state) do { :noreply, state } end
  def handle_info({:tcp, _sock, data}, state) do handle_packet(state, data) end
  def handle_info({:ssl, _sock, data}, state) do handle_packet(state, data) end
  defp handle_packet(state, <<>>) do {:noreply, state} end
  defp handle_packet(state, packet) do
    pres = Nats.Parser.parse(state.ps, packet)
#    IO.puts "received NATS packet: #{inspect(pres)}; raw: #{inspect(packet)}"
    case pres do
      {:ok, msg, rest, nps} ->
        {:noreply, ns } = handle_packet1(%{state | ps: nps}, msg)
        handle_packet(ns, rest)
      other -> nats_err(state, "invalid parser result: #{inspect(other)}")
    end
  end
  defp handle_packet1(state, msg) do
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
  defp nats_err(state, what) do
    IO.puts ("received nats_err: #{inspect(what)}")
    {:noreply, %{state | state: :error}}
  end
  defp check_auth(_json_received, json_to_send, _auth_opts) do
    # FIXME: jam: check auth_required, etc.
    {:noreply, json_to_send }
  end
  defp nats_info(state = %{state: :want_info}, json) do
    # IO.puts "NATS: received INFO: #{inspect(json)}"
    connect_json = %{
        "version" => "elixir-alpha",
        "tls_required" => state.opts.tls_required,
        "verbose" => state.opts.verbose,
    }
    case check_auth(json, connect_json, state.opts.auth) do
      {:noreply, to_send} ->
        if to_send["tls_required"] && false do
          opts = []
          IO.puts "starting SSL handshake:..."
          res = :ssl.connect(state.sock, opts, state.timeout)
          IO.puts "done: #{inspect(res)}"
          {:noreply, port} = res
          state = %{state | sock: port}
        end
        connect(self(), connect_json)
        {:noreply, %{state | state: :connected}}
      {:error, why} -> nats_err(state, why)
    end
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

