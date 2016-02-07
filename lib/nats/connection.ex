# Copyright 2016 Apcera Inc. All rights reserved.
defmodule Nats.Connection do
  use GenServer
  require Logger

  @start_state %{state: :want_connect,
                 sock: nil,
                 worker: nil,
                 send_fn: &:gen_tcp.send/2,
                 close_fn: &:gen_tcp.close/1,
                 opts: %{},
                 ps: nil,
                 ack_ref: nil,
                 writer_pid: nil}

  defp format(x) when is_binary(x), do: x
  defp format(x) when is_list(x), do: Enum.join(Enum.map(x, &(format(&1))), " ")
  defp format(x), do: inspect(x)

  defp _log(level, what) do
    Logger.log level, fn ->
      ((is_list(what) && Enum.join(Enum.map(what, &format/1), ": "))
      || format(what))
    end
  end
#  defp debug_log(what), do: _log(:debug, what)
  defp err_log(what), do: _log(:error, what)
  defp info_log(what), do: _log(:info, what)
  
  def start_link(worker, opts) when is_map (opts) do
#    IO.puts "opts -> #{inspect(opts)}"
    state = @start_state
    state = %{state |
              worker: worker,
              opts: opts,
              ps: nil,
             }
#    debug_log "starting link"
    GenServer.start_link(__MODULE__, state)
  end

  def init(state) do
#    IO.puts "client->  #{inspect(state)}"
    opts = state.opts
    host = opts.host
    port = opts.port
    hpstr = "#{host}:#{port}"
    info_log "connecting to #{hpstr}..."
    case :gen_tcp.connect(to_char_list(host), port,
                          opts.socket_opts,
                          opts.timeout) do
      {:ok, connected} ->
        state = %{state |
                  sock: connected,
                  state: :want_info}
        # FIXME: jam: required?
        :ok = :inet.setopts(connected, state.opts.socket_opts)
        #IO.puts "connected to nats: #{inspect(state)}"
        info_log "connected"
        sender = &(state.send_fn.(connected, &1))
        writer_pid = spawn_link(fn -> write_loop(sender, <<>>, :infinity) end)
        {:ok, %{state | writer_pid: writer_pid}}
      {:error, reason} ->
        why = "error connecting to #{hpstr}: #{reason}"
        err_log why
        {:stop, why}
    end
  end

  defp wait_writer(writer, state) do
    v = send  writer, {:closed, self()}
    if v == nil do
      err_log "writer died?"
      :ok
    else
      receive do
        :closed -> :ok
      after 1_000 ->
#        debug_log "#{inspect self()} didn't get :closed ack back from writer..."
        wait_writer(writer, state)
      end
    end
  end
  def terminate(reason, %{ writer_pid: writer } = state) when writer != nil do
    #    debug_log ["terminating writer", state]
    wait_writer(writer, state)
    terminate(reason, %{ state | writer_pid: nil})
  end
  def terminate(reason, %{ conn: conn } = state) when conn != nil do
    _v = state.close_fn.(conn)
#    debug_log ["connection closed in terminate", _v]
    terminate(reason, %{state | conn: nil})
  end
  def terminate(reason, %{ state: s } = state) when s != :closed do
#    debug_log ["terminating connection", reason, state]
    super(reason, %{state | state: :closed})
  end
  defp handshake_done(state) do
    send state.worker, {:connected, self()}
    {:noreply, %{state | state: :connected, ack_ref: nil}}
  end
  def handle_info({:packet_flushed, ref}, %{state: :ack_connect,
                                            ack_ref: ref} = state) do
#    debug_log "completed handshake"
    aopts = state.opts.auth
    if aopts != nil && Enum.count(aopts) != 0 do
      # FIXME: jam: this is a hack, when doing auth (and other?)
      # handshakes, they may fail but we don't know within a given
      # amount of time, so we need to send a ping and wait for a pong
      # or error...
      # yuck
      send_packet({:write_flush, Nats.Parser.encode({:ping}),
                   true, nil, nil}, state)
      {:noreply, %{state | state: :wait_err_or_pong, ack_ref: nil}}
    else
      handshake_done(state)
    end
  end
  def handle_info({:tcp_closed, msock}, %{sock: s} = state) when s == msock,
    do: nats_err(state, "connection closed")
  def handle_info({:ssl_closed, msock}, %{sock: s} = state) when s == msock,
    do: nats_err(state, "connection closed")
  def handle_info({:tcp_error, msock, reason}, %{sock: s} = state)
    when s == msock,
    do: nats_err(state, "tcp transport error #{inspect(reason)}")
  def handle_info({:tcp_passive, _sock}, state), do: { :noreply, state }
  def handle_info({:tcp, _sock, data}, state), do: transport_input(state, data)
  def handle_info({:ssl, _sock, data}, state), do: transport_input(state, data)
  def handle_cast(write_cmd = {:write_flush, _, _, _, _}, state) do
    send_packet(write_cmd, state)
    {:noreply, state}
  end
  defp send_packet({:write_flush, _cmd, _flush?, _who, _mesg} = write_cmd, 
                   %{writer_pid: writer}) when writer != nil do
#    debug_log ["send packet", write_cmd]
    send writer, write_cmd
    :ok
  end
  defp send_packet(pack, state),
    do: send_packet({:write_flush, pack, false, nil, nil}, state)
    
  @max_buff_size (1024*32)
  @flush_wait_time 20
  defp write_loop(send_fn, acc, howlong) do
    receive do
      {:closed, waiter} ->
        to_write = byte_size(acc)
#        debug_log ["closing", to_write]
        if to_write != 0, do: send_fn.(acc)
        send waiter, :closed
        :ok
      {:write_flush, what, flush?, who, ack_mesg} ->
        if what != nil, do: acc = acc <> what
        to_write = byte_size(acc)
        if to_write != 0 && (to_write >= @max_buff_size || flush?) do
#          debug_log ["buffer write/flush", to_write, "/#{flush?}"]
          send_fn.(acc)
          acc = <<>>
          howlong = :infinity
        else
#          debug_log ["buffer write/flush", to_write, ?\/, flush?,
#                            " (buffering)"]
          howlong = @flush_wait_time
        end
        if who, do: send who, ack_mesg
        write_loop(send_fn, acc, howlong)
    after howlong -> 
        howlong = :infinity
        to_write = byte_size(acc)
#        debug_log ["time flush", to_write]
        if to_write != 0 do
          send_fn.(acc)
          acc = <<>>
        end
        write_loop(send_fn, acc, howlong)
    end
  end
  
  defp transport_input(state, pack) do
    res = handle_packet(state, pack)
    :ok = :inet.setopts(state.sock, [active: :once])
    res
  end
  defp handle_packet(state, <<>>), do: {:noreply, state}
  defp handle_packet(state, packet) do
#    debug_log ["received packet", packet]
    pres = Nats.Parser.parse(state.ps, packet)
#    debug_log ["parsed packet", pres]
    case pres do
      {:ok, msg, rest, nps} ->
#        debug_log ["parsed packet", msg]
        case handle_packet1(%{state | ps: nps}, msg) do
          {:noreply, ns } -> handle_packet(ns, rest)
          other -> other
        end
      {:cont, _howmany, nps} ->
#        debug_log ["partial packet", howmany]
        {:noreply, %{state | ps: nps}}
      other -> nats_err(state, "invalid parser result: #{inspect(other)}")
    end
  end
  defp handle_packet1(state, msg) do
#    debug_log ["dispatching packet", elem(msg, 0)]
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
    err_log  what
#    send state.worker, {:error, self(), what}
    {:stop, "NATS err: #{inspect(what)}", %{state | state: :error}}
  end
  defp check_auth(_state,
                  json_received = %{},
                  json_to_send = %{}, auth_opts = %{}) do
    server_want_auth = json_received["auth_required"] || false
    we_want_auth = Enum.count(auth_opts) != 0
    auth_match = {server_want_auth, we_want_auth}
#    debug_log ["checking auth", auth_match]
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
#          debug_log ["upgrading to tls with", opts]
          res = :ssl.connect(state.sock, opts, state.opts.timeout)
#          debug_log ["tls handshake completed", res]
          {:ok, port} = res
          state = %{state |
                    sock: port, send_fn: &:ssl.send/2, close_fn: &:ssl.close/1}
        end
        #        debug_log "handshake: writing connect and waiting for ack"
        ack_ref = make_ref()
        handshake = {:write_flush, Nats.Parser.encode({:connect, to_send}),
                     true, self(), {:packet_flushed, ack_ref}}
        send_packet(handshake, state)
        {:noreply, %{state | state: :ack_connect, ack_ref: ack_ref}}
      {:error, why} -> nats_err(state, why)
    end
  end
  defp nats_info(state, json) do
    info_log ["received INFO after handshake", json]
    {:noreply, state}
  end
  # For server capabilities ;-)
  defp nats_connect(state = %{state: :want_connect}, _json) do
#    debug_log "received connect; transitioning to connected"
    {:noreply, %{state | state: :server_connected}}
  end
  defp nats_connect(state, json) do
    err_log ["received CONNECT after handshake", json]
    {:noreply, state}
  end
  defp nats_ping(state) do
    send_packet({:write_flush, Nats.Parser.encode({:pong}),
                 true, nil, nil}, state);
    {:noreply, state}
  end
  defp nats_pong(state = %{ state: :wait_err_or_pong}),
    # When we are hanshaking we need to look for an err or
    # returning pong, otherwise there is no way to know for sure
    # whether things worked out
    do: handshake_done(state)
  defp nats_pong(state), do: {:noreply, state}
  defp nats_ok(state), do: {:noreply, state}
  defp nats_msg(state = %{state: :connected}, sub, sid, ret, body) do
#    debug_log  ["received MSG", sub, sid, ret, body]
    send state.worker, {:msg, sub, sid, ret, body}
    {:noreply, state}
  end
  defp nats_pub(state = %{state: :connected}, _sub, _ret, _body) do
#    debug_log ["received PUB", sub, ret, body]
    {:noreply, state}
  end
  defp nats_unsub(state = %{state: :connected}, _sid, _how_many) do
#    debug_log ["received UNSUB", sid, how_many]
    {:noreply, state}
  end
end
