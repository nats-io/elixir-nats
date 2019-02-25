# Copyright 2016 Apcera Inc. All rights reserved.
defmodule Nats.Connection do
  use GenServer
  require Logger

  @start_state %{
    state: :want_connect,
    make_active: true,
    sock: nil,
    worker: nil,
    send_fn: &:gen_tcp.send/2,
    close_fn: &:gen_tcp.close/1,
    # do we start up a separate aagent to do sends?
    sep_writer: true,
    opts: %{},
    ps: nil,
    ack_ref: nil,
    writer_pid: nil
  }

  defp format(x) when is_binary(x), do: x
  defp format(x) when is_list(x), do: Enum.join(Enum.map(x, &format(&1)), " ")
  defp format(x), do: inspect(x)

  defp _log(level, what) do
    #    IO.puts ((is_list(what) && Enum.join(Enum.map(what, &format(&1)), ": ")) || format(what))
    Logger.log(level, fn ->
      (is_list(what) && Enum.join(Enum.map(what, &format/1), ": ")) || format(what)
    end)
  end

  #  defp debug_log(what), do: _log(:debug, what)
  defp err_log(what), do: _log(:error, what)
  defp info_log(what), do: _log(:info, what)

  def start_link(worker, opts) when is_map(opts) do
    #    IO.puts "opts -> #{inspect(opts)}"
    state = @start_state
    state = %{state | worker: worker, opts: opts, ps: nil}
    # debug_log "starting link"
    GenServer.start_link(__MODULE__, state)
  end

  def init(state) do
    #    IO.puts "client->  #{inspect(state)}"
    opts = state.opts
    host = opts.host
    port = opts.port
    hpstr = "#{host}:#{port}"
    info_log("connecting to #{hpstr}...")

    case :gen_tcp.connect(to_charlist(host), port, opts.socket_opts, opts.timeout) do
      {:ok, connected} ->
        state = %{state | sock: connected, state: :want_info}
        # FIXME: jam: required?
        :ok = :inet.setopts(connected, state.opts.socket_opts)
        info_log("connected")

        state =
          if state.sep_writer do
            sender = &state.send_fn.(connected, &1)
            writer_pid = spawn_link(fn -> write_loop(sender, [], 0, :infinity) end)
            %{state | writer_pid: writer_pid}
          else
            state
          end

        {:ok, state}

      {:error, reason} ->
        why = "error connecting to #{hpstr}: #{reason}"
        err_log(why)
        {:stop, why}
    end
  end

  defp wait_writer(writer, state) do
    if Process.alive?(writer) do
      receive do
        :closed -> :ok
      after
        1_000 ->
          # FIXME: jam: hook up to sup tree
          #        err_log "#{inspect self()} didn't get :closed ack back from writer..."
          err_log(["waiting for waiter ack...", writer, state])
          wait_writer(writer, state)
      end
    else
      receive do
        :closed -> :ok
      after
        0 ->
          err_log(["writer died", writer, state])
          :ok
      end
    end
  end

  def terminate(reason, %{writer_pid: writer, sep_writer: true} = state)
      when not is_nil(writer) do
    #    err_log ["terminating writer", state]
    send(writer, {:closed, self()})
    wait_writer(writer, state)
    terminate(reason, %{state | writer_pid: nil})
  end

  def terminate(reason, %{sock: conn} = state) when not is_nil(conn) do
    #    _v = state.close_fn.(conn)
    #    err_log ["closing connection in terminate", 0]
    #    IO.puts "connection closed in terminate: #{inspect v}"
    terminate(reason, %{state | sock: nil})
  end

  def terminate(_reason, %{state: s} = state) when s != :closed do
    #    IO.puts "terminate!!"
    state = %{state | state: :closed}
    {:noreply, state}
  end

  defp handshake_done(state) do
    #    err_log "handshake done"
    send(state.worker, {:connected, self()})
    {:noreply, %{state | state: :connected, ack_ref: nil}}
  end

  defp tls_handshake(%{opts: %{tls_required: true}} = state) do
    # start our TLS handshake...
    opts = state.opts
    info_log(["upgrading to tls with timeout", opts.timeout, "ssl_opts", opts.ssl_opts])
    :ok = :inet.setopts(state.sock, active: true)

    case :ssl.connect(state.sock, opts.ssl_opts, opts.timeout) do
      {:ok, port} ->
        #        debug_log ["tls handshake completed"]
        if state.sep_writer do
          new_sender = &:ssl.send(port, &1)
          send(state.writer_pid, {:sender_changed, new_sender})
        end

        {:ok,
         %{state | sock: port, send_fn: &:ssl.send/2, close_fn: &:ssl.close/1, make_active: false}}

      {:error, why} ->
        info_log(["tls_handshake failed", why])
        {:error, why, state}
    end
  end

  defp tls_handshake(%{opts: %{tls_required: false}} = state), do: {:ok, state}

  def handle_info(
        {:packet_flushed, _, ref},
        %{state: :ack_connect, ack_ref: ref} = state
      ) do
    # debug_log "completed handshake: #{inspect res}"
    aopts = state.opts.auth

    if aopts != nil && Enum.count(aopts) != 0 do
      # FIXME: jam: this is a hack, when doing auth (and other?)
      # handshakes, they may fail but we don't know within a given
      # amount of time, so we need to send a ping and wait for a pong
      # or error...
      # yuck
      send_packet(
        {:write_flush, Nats.Parser.encode({:ping}), true, nil},
        state
      )

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

  def handle_info({:tcp_passive, _sock}, state) do
    #      IO.puts "passiv!!!"
    {:noreply, state}
  end

  def handle_info({:tcp, _sock, data}, state), do: transport_input(state, data)
  def handle_info({:ssl, _sock, data}, state), do: transport_input(state, data)

  def handle_cast(write_cmd = {:write_flush, _, _, _}, state) do
    send_packet(write_cmd, state)
    {:noreply, state}
  end

  defp send_packet(
         {:write_flush, _what, _flush?, ack_mesg} = write_cmd,
         %{writer_pid: writer}
       )
       when is_pid(writer) do
    # debug_log ["send packet", write_cmd]
    # debug_log "send packet #{inspect flush?} #{inspect from} #{inspect writer} #{Process.alive?(writer)}"
    if Process.alive?(writer) do
      send(writer, write_cmd)
    else
      # err_log("DEAD!!!")
      case ack_mesg do
        {:packet_flushed, who, _ref} -> send(who, ack_mesg)
        nil -> nil
        _ -> GenServer.reply(ack_mesg, :ok)
      end
    end

    :ok
  end

  #  defp send_packet(pack, state),
  #    do: send_packet({:write_flush, pack, false, nil, nil}, state)
  defp send_packet(
         {:write_flush, to_write, _flush?, ack_mesg},
         %{sock: s, send_fn: send_fn, sep_writer: false}
       ) do
    # err_log "send_packet-> open=#{s != nil} flush?=#{flush?} write?=#{not is_nil(to_write)} ack?=#{not is_nil(ack_mesg)}"
    # err_log "send_packet-> open=#{s != nil} flush?=#{inspect to_write} ack?=#{not is_nil(ack_mesg)}"
    if s != nil and to_write != nil do
      case to_write do
        {:msg, _what_len, what} ->
          # err_log ["wrote some bytes #{inspect what}", ack_mesg, what, v]
          send_fn.(s, what)
      end
    end

    case ack_mesg do
      {:packet_flushed, who, _ref} -> send(who, ack_mesg)
      nil -> nil
      _ -> GenServer.reply(ack_mesg, :ok)
    end

    :ok
  end

  @max_buff_size 32 * 1024
  @flush_wait_time 24
  @min_flush_wait_time 2
  defp write_loop(send_fn, acc, acc_size, howlong) do
    # err_log("entering receive: acc_size=#{acc_size} howlong=#{howlong}")

    receive do
      {:sender_changed, send_fn} ->
        # info_log(["sender changed", send_fn])
        write_loop(send_fn, acc, acc_size, howlong)

      {:closed, waiter} ->
        # info_log(["closing", acc_size])
        if acc_size != 0, do: send_fn.(acc)
        send(waiter, :closed)

      # write_loop(nil, [], 0, :infinity)

      {:write_flush, w, flush?, ack_mesg} ->
        {acc, acc_size} =
          case w do
            {:msg, what_len, what} ->
              if what_len != 0 do
                acc = [acc | what]
                acc_size = acc_size + what_len
                if IO.iodata_length(what) != what_len, do: exit(1)
                {acc, acc_size}
              else
                {acc, acc_size}
              end

            nil ->
              {acc, acc_size}

            _ ->
              {acc, acc_size}
          end

        {acc, acc_size, howlong} =
          if acc_size != 0 do
            if flush? || acc_size >= @max_buff_size do
              :ok = send_fn.(acc)
              {[], 0, :infinity}
            else
              howlong =
                case howlong do
                  :infinity ->
                    @flush_wait_time

                  x when x <= @min_flush_wait_time ->
                    0

                  x ->
                    div(x, 3)
                end

              # err_log ["buffer write/flush", acc_size, "/", flush?, " (buffering)", howlong]
              {acc, acc_size, howlong}
            end
          else
            {acc, acc_size, :infinity}
          end

        case ack_mesg do
          {:packet_flushed, who, _ref} ->
            send(who, ack_mesg)

          nil ->
            nil

          other ->
            GenServer.reply(other, :ok)
        end

        write_loop(send_fn, acc, acc_size, howlong)
    after
      howlong ->
        # err_log [">time flush", acc_size]
        :ok = send_fn.(acc)
        # err_log ["<time flush", acc_size]
        write_loop(send_fn, [], 0, :infinity)
    end
  end

  defp transport_input(%{make_active: make_active} = state, pack) do
    res = handle_packet(state, pack)
    if make_active, do: :ok = :inet.setopts(state.sock, active: :once)
    res
  end

  defp handle_packet(state, <<>>), do: {:noreply, state}

  defp handle_packet(state, packet) do
    # debug_log(["received packet", packet])
    pres = Nats.Parser.parse(state.ps, packet)
    # debug_log(["parsed packet", pres])

    case pres do
      {:ok, msg, rest, nps} ->
        # err_log ["dispatching packet", msg] # elem(msg, 0)]
        state = %{state | ps: nps}

        res =
          case msg do
            {:info, json} -> nats_info(state, json)
            {:connect, json} -> nats_connect(state, json)
            {:ping} -> nats_ping(state)
            {:pong} -> nats_pong(state)
            {:ok} -> nats_ok(state)
            {:err, why} -> nats_err(state, why)
            {:msg, _sub, _sid, _ret, _body} -> nats_msg(state, msg)
            {:pub, sub, rep, what} -> nats_pub(state, sub, rep, what)
            {:unsub, sid, howMany} -> nats_unsub(state, sid, howMany)
            _ -> nats_err(state, "received bad NATS verb: -> #{inspect(msg)}")
          end

        case res do
          {:noreply, ns} -> handle_packet(ns, rest)
          other -> other
        end

      {:cont, _howmany, nps} ->
        # debug_log ["partial packet", howmany]
        {:noreply, %{state | ps: nps}}

      other ->
        nats_err(state, "invalid parser result: #{inspect(other)}")
    end
  end

  defp nats_err(%{state: :error} = s, what) do
    #    info_log  ["DOUBLE (or more) ERROR!!!", what]
    {:stop, what, s}
  end

  defp nats_err(state, what) do
    #    info_log  what
    send(state.worker, {:error, self(), what})
    {:stop, what, %{state | state: :error}}
  end

  defp check_auth(_state, json_received = %{}, json_to_send = %{}, auth_opts = %{}) do
    server_want_auth = json_received["auth_required"] || false
    we_want_auth = Enum.count(auth_opts) != 0
    auth_match = {server_want_auth, we_want_auth}
    # info_log(["checking auth", auth_match])

    case auth_match do
      {x, x} -> {:ok, Map.merge(json_to_send, auth_opts)}
      _ -> {:error, "client and server disagree on authorization"}
    end
  end

  defp nats_info(
         state = %{state: :want_info, opts: %{tls_required: we_want}},
         %{"tls_required" => server_tls}
       )
       when we_want != server_tls do
    nats_err(state, "server and client disagree on tls (#{server_tls} vs #{we_want})")
  end

  defp nats_info(state = %{state: :want_info}, json) do
    # info_log("NATS: received INFO: #{inspect(json)}")

    connect_json = %{
      "version" => "0.1.4",
      "name" => "elixir-nats",
      "lang" => "elixir",
      "pedantic" => false,
      "verbose" => state.opts.verbose
    }

    case check_auth(state, json, connect_json, state.opts.auth) do
      {:ok, to_send} ->
        # THIS MAY UPDATE THE SOCKET!!!
        case tls_handshake(state) do
          {:ok, state} ->
            # info_log("handshake: writing connect and waiting for ack")
            ack_ref = make_ref()

            handshake =
              {:write_flush, Nats.Parser.encode({:connect, to_send}), true,
               {:packet_flushed, self(), ack_ref}}

            state = %{state | state: :ack_connect, ack_ref: ack_ref}
            send_packet(handshake, state)
            {:noreply, state}

          {:error, why, state} ->
            nats_err(state, "ssl handshake failed: #{inspect(why)}")
        end

      {:error, why} ->
        nats_err(state, why)
    end
  end

  defp nats_info(state, _json) do
    # info_log(["received INFO after handshake", json])
    {:noreply, state}
  end

  # For server capabilities ;-)
  defp nats_connect(state = %{state: :want_connect}, _json) do
    info_log("received connect; transitioning to connected")
    {:noreply, %{state | state: :server_connected}}
  end

  defp nats_connect(state, json) do
    err_log(["received CONNECT after handshake", json])
    {:noreply, state}
  end

  defp nats_ping(state) do
    send_packet(
      {:write_flush, Nats.Parser.encode({:pong}), true, nil},
      state
    )

    {:noreply, state}
  end

  defp nats_pong(state = %{state: :wait_err_or_pong}),
    # When we are hanshaking we need to look for an err or
    # returning pong, otherwise there is no way to know for sure
    # whether things worked out
    do: handshake_done(state)

  defp nats_pong(state), do: {:noreply, state}
  defp nats_ok(state), do: {:noreply, state}

  defp nats_msg(state = %{state: :connected}, msg) do
    # debug_log  ["received MSG", sub, sid, ret, body]
    send(state.worker, msg)
    {:noreply, state}
  end

  defp nats_pub(state = %{state: :connected}, _sub, _ret, _body) do
    # debug_log ["received PUB", sub, ret, body]
    {:noreply, state}
  end

  defp nats_unsub(state = %{state: :connected}, _sid, _how_many) do
    # debug_log ["received UNSUB", sid, how_many]
    {:noreply, state}
  end

  def stop(self) do
    GenServer.stop(self)
  end
end
