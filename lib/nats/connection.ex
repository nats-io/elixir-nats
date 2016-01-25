defmodule Nats.Connection do
  use GenServer
  require Logger

  @default_host '127.0.0.1'
  @default_port 4222
  @default_timeout 5000
  
  @start_state %{state: :want_info,
                 sock: nil,
                 send_fn: &:gen_tcp.send/2,
                 opts: %{tls_required: false, auth: %{}, # "user" => "user",
                                                       # "pass" => "pass"},
                         verbose: false,
                         timeout: @default_timeout,
                         host: @default_host, port: @default_port,
                         socket_opts: [:binary, active: true],
                         ssl_opts: []},
                 ps: nil,
                 log_header: nil}

  defp format(x) when is_binary(x) do x end
  defp format(x) when is_list(x) do Enum.join(Enum.map(x, &(format(&1))),
                                                  " ") end
  defp format(x), do: inspect(x)
  defp log(level, state, what) do
    Logger.log level, fn ->
#      if is_list(what), do: what = Enum.join(what, " ")
      Enum.join([state.log_header, format(what)], ": ")
    end
  end
  defp debug_log(state, what), do: log(:debug, state, what)
  defp err_log(state, what), do: log(:error, state, what)
  defp info_log(state, what), do: log(:info, state, what)
  

  
  def start_link do start_link(@default_host, @default_port) end
  def start_link(host, port \\ @default_port) do
    state = @start_state
    state = %{state | opts: %{state.opts | host: host, port: port},
              log_header: "NATS: #{inspect(self())}@#{host}:#{port}: "
             }
    debug_log state, "starting link"
    GenServer.start_link(__MODULE__, state)
  end
  def init(state) do
    debug_log state, "connecting"
    {:ok, connected} = :gen_tcp.connect(state.opts.host,
                                        state.opts.port,
                                        state.opts.socket_opts,
                                        state.opts.timeout)
    ns = %{state | sock: connected}
    # FIXME: jam: required?
    :ok = :inet.setopts(connected, state.opts.socket_opts)
    #IO.puts "connected to nats: #{inspect(ns)}"
    info_log state, "connected"
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
    debug_log state, ["sending", pack]
    case state.send_fn.(state.sock, pack) do
      :ok ->
        debug_log state, ["sent", pack]
      {:error, :closed} -> err_log state, "socket closed"
      oops -> err_log state, ["unexpected send result", oops]
    end
    {:noreply, state}
  end
  def handle_info({:tcp_closed, _sock}, state) do
    nats_err(state, "connection closed")
#    { :noreply, %{ state }
  end
  def handle_info({:tcp_error, _sock, reason}, state) do
    nats_err(state, "tcp transport error #{inspect(reason)}")
    { :noreply, state }
  end
  def handle_info({:tcp_passive, _sock}, state) do { :noreply, state } end
  def handle_info({:tcp, _sock, data}, state) do handle_packet(state, data) end
  def handle_info({:ssl, _sock, data}, state) do handle_packet(state, data) end
  defp handle_packet(state, <<>>) do {:noreply, state} end
  defp handle_packet(state, packet) do
    debug_log state, ["received packet", packet]
    pres = Nats.Parser.parse(state.ps, packet)
    case pres do
      {:ok, msg, rest, nps} ->
        debug_log state, ["parsed packet", msg]
        {:noreply, ns } = handle_packet1(%{state | ps: nps}, msg)
        handle_packet(ns, rest)
      other -> nats_err(state, "invalid parser result: #{inspect(other)}")
    end
  end
  defp handle_packet1(state, msg) do
    debug_log state, ["dispatching packet", elem(msg, 0)]
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
    err_log state, what
    {:noreply, %{state | state: :error}}
  end
  defp check_auth(state,
                  json_received = %{},
                  json_to_send = %{}, auth_opts = %{}) do
    server_want_auth = json_received["auth_required"] || false
    we_want_auth = Enum.count(auth_opts) != 0
    auth_match = {server_want_auth, we_want_auth}
    info_log state, ["checking auth", auth_match]
    case auth_match do
      {x, x} -> {:ok, Map.merge(json_to_send, auth_opts)}
      _ -> {:error, "client and server disagree on authorization"}
    end
  end
  defp nats_info(state = %{state: :want_info}, json) do
    # IO.puts "NATS: received INFO: #{inspect(json)}"
    connect_json = %{
        "version" => "elixir-alpha",
        "tls_required" => state.opts.tls_required,
        "verbose" => state.opts.verbose,
    }
    case check_auth(state, json, connect_json, state.opts.auth) do
      {:ok, to_send} ->
        if to_send["tls_required"] do
          opts = state.opts.ssl_opts
          info_log state, ["upgrading to tls with", opts]
          res = :ssl.connect(state.sock, opts, state.opts.timeout)
          info_log state, ["tls handshake completed", res]
          {:ok, port} = res
          state = %{state | sock: port, send_fn: &:ssl.send/2}
        end
        debug_log state, "completing handshake"
        connect(self(), to_send)
        debug_log state, "handshake completed"
        {:noreply, %{state | state: :connected}}
      {:error, why} -> nats_err(state, why)
    end
  end
  defp nats_info(state, json) do
    info_log state, ["received INFO after handshake", json]
    {:noreply, state}
  end
  defp nats_connect(state = %{state: :want_connect}, _json) do
    debug_log state, "received connect; transitioning to connected"
    {:noreply, %{state | state: :connected}}
  end
  defp nats_connect(state, json) do
    err_log state, ["received CONNECT after handshake", json]
    {:noreply, state}
  end
  defp nats_ping(state) do
    pong(self())
    {:noreply, state}
  end
  defp nats_pong(state) do
    {:noreply, state}
  end
  defp nats_ok(state) do
    {:noreply,state}
  end
  defp nats_msg(state = %{state: :connected}, sub, sid, ret, body) do
    debug_log state, ["MSG sub", sub, "sid", sid, "ret", ret, "body", body]
    {:noreply, state}
  end
  defp nats_msg(state, _sub, _sid, _ret, _what) do
    err_log state, ["received MSG before handshake"]
    {:noreply, state}
  end
  defp nats_pub(state = %{state: :connected}, sub, ret, body) do
    debug_log state, ["received PUB: sub", sub, "ret", ret, "body", body]
    {:noreply, state}
  end
  defp nats_pub(state, _sub, _ret, _what) do
    err_log state, "received PUB before handshake"
    {:noreply, state}
  end
end

