# Copyright 2016 Apcera Inc. All rights reserved.
defmodule Nats.Connection do
  use GenServer
  require Logger

  @start_state %{state: :want_info,
                 sock: nil,
                 worker: nil,
                 send_fn: &:gen_tcp.send/2,
                 opts: %{},
                 ps: nil,
                 log_header: nil}

  defp format(x) when is_binary(x), do: x
  defp format(x) when is_list(x), do: Enum.join(Enum.map(x, &(format(&1))), " ")
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
  
  def start_link(worker, opts) when is_map (opts) do
#    IO.puts "opts -> #{inspect(opts)}"
    state = @start_state
    state = %{state |
              worker: worker,
              opts: opts,
              ps: nil,
              log_header: "NATS: #{inspect(self())}: "
             }
    debug_log state, "starting link"
    GenServer.start_link(__MODULE__, state)
  end

  def init(state) do
#    IO.puts "client->  #{inspect(state)}"
    opts = state.opts
    host = opts.host
    port = opts.port
    hpstr = "#{host}:#{port}"
    info_log state, "connecting to #{hpstr}..."
    case :gen_tcp.connect(to_char_list(host), port,
                          opts.socket_opts,
                          opts.timeout) do
      {:ok, connected} ->
        state = %{state |
                  sock: connected,
                  log_header: state.log_header <> "#{hpstr}: "}
        # FIXME: jam: required?
        :ok = :inet.setopts(connected, state.opts.socket_opts)
        #IO.puts "connected to nats: #{inspect(state)}"
        info_log state, "connected"
        {:ok, state}
      {:error, reason} ->
        why = "error connecting to #{hpstr}: #{reason}"
        err_log(state, why)
        {:stop, why}
    end
  end

  def ping(self), do: (send self, {:ping}; :ok)
  def pong(self), do: (send self, {:pong}; :ok)
  def ok(self), do: (send self, {:ok}; :ok)
  def info(self, map), do: (send self, {:info, map}; :ok)
  def connect(self, map), do: (send self, {:connect, map}; :ok)
  def error(self, msg), do: (send self, {:err, msg}; :ok)
  def sub(self, subject), do: sub(self, subject, nil, subject)
  def sub(self, subject, sid), do: sub(self, subject, nil, sid)
  def sub(self, subject, queue, sid) do
    send self, {:sub, subject, queue, sid}
    :ok
  end
  def pub(self, subject, what), do: pub(self, subject, nil, what)
  def pub(self, subject, reply, what) do
    send self, {:pub, subject, reply, what}
    :ok
  end
  def msg(self, subject, what), do: msg(self, subject, subject, what)
  def msg(self, subject, sid, what), do: msg(self, subject, sid, nil, what)
  def msg(self, subject, sid, reply_queue, what) do
    send self, {:msg, subject, sid, reply_queue, what}
    :ok
  end
  def handle_info({:tcp_closed, _sock}, state),
    do: nats_err(state, "connection closed")
  def handle_info({:ssl_closed, _sock}, state),
    do: nats_err(state, "connection closed")
  def handle_info({:tcp_error, _sock, reason},
                  state),
    do: nats_err(state, "tcp transport error #{inspect(reason)}")
  def handle_info({:tcp_passive, _sock}, state), do: { :noreply, state }
  def handle_info({:tcp, _sock, data}, state), do: handle_packet(state, data)
  def handle_info({:ssl, _sock, data}, state), do: handle_packet(state, data)
  def handle_info(cmd, state) do
#    IO.puts "cmd -> #{inspect(cmd)}"
    pack = Nats.Parser.encode(cmd)
    debug_log state, ["sending", pack]
    case state.send_fn.(state.sock, pack) do
      :ok -> debug_log state, ["sent", pack]
      {:error, :closed} -> info_log state, "socket closed"
      oops -> err_log state, ["unexpected send result", oops]
    end
    {:noreply, state}
  end
  defp handle_packet(state, <<>>), do: {:noreply, state}
  defp handle_packet(state, packet) do
    debug_log state, ["received packet", packet]
    pres = Nats.Parser.parse(state.ps, packet)
    debug_log state, ["parsed packet", pres]
    case pres do
      {:ok, msg, rest, nps} ->
        debug_log state, ["parsed packet", msg]
        case handle_packet1(%{state | ps: nps}, msg) do
          {:noreply, ns } -> handle_packet(ns, rest)
          other -> other
        end
      {:cont, howmany, nps} ->
        debug_log state, ["partial packet", howmany]
        {:noreply, %{state | ps: nps}}
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
      {:unsub, sid, howMany} -> nats_unsub(state, sid, howMany)
      _ -> nats_err(state, "received bad NATS verb: -> #{inspect(msg)}")
    end
  end
  defp nats_err(state, what) do
    err_log state, what
#    send state.worker, {:error, self(), what}
    {:stop, "NATS err: #{inspect(what)}", %{state | state: :error}}
  end
  defp check_auth(state,
                  json_received = %{},
                  json_to_send = %{}, auth_opts = %{}) do
    server_want_auth = json_received["auth_required"] || false
    we_want_auth = Enum.count(auth_opts) != 0
    auth_match = {server_want_auth, we_want_auth}
    debug_log state, ["checking auth", auth_match]
    case auth_match do
      {x, x} -> {:ok, Map.merge(json_to_send, auth_opts)}
      _ -> {:error, "client and server disagree on authorization"}
    end
  end
  defp nats_info(state = %{state: :want_info, opts: %{ tls_required: we_want }},
                 connect_json = %{ "tls_required" => server_tls })
  when we_want != server_tls do
    why = "server and client disagree on tls (#{server_tls} vs #{we_want})"
    nats_err(state, [why, "INFO json", connect_json])
  end
  defp nats_info(state = %{state: :want_info}, json) do
    # IO.puts "NATS: received INFO: #{inspect(json)}"
    connect_json = %{
      "version" => "0.1.4",
      "name" => "elixir-nats",
      "lang" => "elixir",
      "pedantic" => false,
      "verbose" => state.opts.verbose,
    }
    case check_auth(state, json, connect_json, state.opts.auth) do
      {:ok, to_send} ->
        if state.opts.tls_required do
          opts = state.opts.ssl_opts
          debug_log state, ["upgrading to tls with", opts]
          res = :ssl.connect(state.sock, opts, state.opts.timeout)
          debug_log state, ["tls handshake completed", res]
          {:ok, port} = res
          state = %{state | sock: port, send_fn: &:ssl.send/2}
        end
        debug_log state, "completing handshake"
        handle_info({:connect, to_send}, state)
        debug_log state, "handshake completed"
        send state.worker, {:connected, self()}
        {:noreply, %{state | state: :connected}}
      {:error, why} -> nats_err(state, why)
    end
  end
  defp nats_info(state, json) do
    info_log state, ["received INFO after handshake", json]
    {:noreply, state}
  end
  # For server capabilities ;-)
  defp nats_connect(state = %{state: :want_connect}, _json) do
    debug_log state, "received connect; transitioning to connected"
    {:noreply, %{state | state: :server_connected}}
  end
  defp nats_connect(state, json) do
    err_log state, ["received CONNECT after handshake", json]
    {:noreply, state}
  end
  defp nats_ping(state) do
    handle_info({:pong}, state)
  end
  defp nats_pong(state) do
    {:noreply, state}
  end
  defp nats_ok(state) do
    {:noreply, state}
  end
  defp nats_msg(state = %{state: :connected}, sub, sid, ret, body) do
    debug_log state, ["received MSG", sub, sid, ret, body]
    send state.worker, {:msg, sub, sid, ret, body}
    {:noreply, state}
  end
  defp nats_pub(state = %{state: :connected}, sub, ret, body) do
    debug_log state, ["received PUB", sub, ret, body]
    {:noreply, state}
  end
  defp nats_unsub(state = %{state: :connected}, sid, howMany) do
    debug_log state, ["received UNSUB", sid, howMany]
    {:noreply, state}
  end
end
