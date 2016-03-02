# Copyright 2016 Apcera Inc. All rights reserved.
defmodule Nats.Client do
  use GenServer
  require Logger

  alias Nats.Connection
  
  @default_host "127.0.0.1"
  @default_port 4222
  @default_timeout 5000

  @default_opts %{ tls_required: false,
                   auth: %{}, # "user" => "user", "pass" => "pass"},
                   verbose: false,
                   timeout: @default_timeout,
                   host: @default_host, port: @default_port,
                   socket_opts: [:binary, active: :once],
                   ssl_opts: []}
  @start_state %{ conn: nil, opts: %{}, status: :starting, why: nil,
                  subs_by_pid: %{},
                  subs_by_sid: %{},
                  opts: @default_opts,
                  next_sid: 0}

  def start_link(opts \\ %{}) do
    GenServer.start_link(__MODULE__, Map.merge(@default_opts, opts))
  end
  def start(opts \\ %{}) do
    GenServer.start(__MODULE__, Map.merge(@default_opts, opts))
  end

  def init(orig_opts) do
#    IO.puts "init! #{inspect(opts)}"
    state = @start_state
    opts = Map.merge(state.opts, orig_opts)
    parent = self()
    case Connection.start_link(parent, opts) do
      {:ok, x}  when is_pid(x) ->
        receive do
          {:connected, ^x } ->
            {:ok, %{state | conn: x, status: :connected, opts: opts}}
        after opts.timeout ->
            {:stop, "timeout connecting to NATS"}
        end
      other -> {:error, "unable to start connection link", other}
    end
  end

  def handle_info({:msg, subject, sid, reply, what},
                  state = %{ subs_by_sid: subs_by_sid,
                             status: client_status})
  when client_status != :closed do
    pid = Map.get(subs_by_sid, sid)
    if pid, do: send pid, {:msg, {sid, pid}, subject, reply, what}
    {:noreply, state}
  end
  # ignore messages we get after being closed...
  def handle_info({:msg, _subject, _sid, _reply, _what}, state) do
    {:noreply, state}
  end
  def terminate(reason, state = %{status: status}) when status != :closed do
    #    Logger.log :info, "terminating client: #{inspect reason}: #{inspect state}"
    :ok = Connection.stop(state.conn)
    state = %{state | conn: nil, status: :closed}
    super(reason, state)
  end
  defp send_cmd(state, cmd),
    do: send_cmd(state, Nats.Parser.encode(cmd), false, nil)
  defp send_cmd(state, cmd, flush?, from),
    do: GenServer.cast(state.conn,
                       {:write_flush, cmd, flush?, from})
  # return an error for any calls after we are closed!
  def handle_call(_call, _from, state = %{status: :closed}) do
    {:reply, {:error, "connection closed"}, state}
  end
  def handle_call({:unsub, ref = {sid, who}, afterReceiving}, _from,
                  state = %{subs_by_sid: subs_by_sid,
                            subs_by_pid: subs_by_pid}) do
    case Map.get(subs_by_sid, sid, nil) do
      ^who ->
        other_subs_for_pid = Map.delete(Map.get(subs_by_pid, who), sid)
#        IO.puts "other_subs_for_pid(#{Map.size(other_subs_for_pid)}->#{inspect other_subs_for_pid}"
        if Map.size(other_subs_for_pid) > 0 do
          subs_by_pid = Map.put(subs_by_pid, who, other_subs_for_pid)
        else
#          IO.puts "deleting..."
          # don't carry around empty maps in our state for this pid
          subs_by_pid = Map.delete(subs_by_pid, who)
        end
        state = %{state |
                  subs_by_sid: Map.delete(subs_by_sid, sid),
                  subs_by_pid: subs_by_pid}        
        send_cmd(state, {:unsub, sid, afterReceiving})
        {:reply, :ok, state}
      nil ->
        {:reply, {:error, {"not subscribed", ref}}, state}
      _ ->
        {:reply, {:error, {"wrong subscriber process", ref}}, state}
    end
  end
  def handle_call({:sub, who, subject, queue}, _from,
                  state = %{subs_by_sid: subs_by_sid,
                            subs_by_pid: subs_by_pid,
                            next_sid: next_sid}) do
    sid = Integer.to_string(next_sid)
    m = Map.get(subs_by_pid, who, %{})
    ref = {sid, who}
    m = Map.put(m, sid, ref)
    subs_by_pid = Map.put(subs_by_pid, who, m)
    subs_by_sid = Map.put(subs_by_sid, sid, who)
    state = %{state |
              subs_by_sid: subs_by_sid,
              subs_by_pid: subs_by_pid,
              next_sid: next_sid + 1}
    send_cmd(state, {:sub, subject, queue, sid})
    # IO.puts "subscribed!! #{inspect(state)}" 
    {:reply, {:ok, {sid, who}}, state}
  end
  def handle_call({:cmd, encoded, flush?} , from,
                  state = %{status: client_status})
  when client_status != :closed do
    # cast to the connection, and let it respond
    send_cmd(state, encoded, flush?, from)
    {:noreply, state}
  end
 
  def pub(self, subject, what) do pub(self, subject, nil, what) end
  def pub(self, subject, reply, what),
    do: GenServer.call(self, {:cmd,
                              Nats.Parser.encode({:pub, subject,
                                                  reply, what}),
                              false})
  def sub(self, who, subject, queue \\ nil),
    do: GenServer.call(self, {:sub, who, subject, queue})
  def unsub(self, ref, afterReceiving \\ nil),
    do: GenServer.call(self, {:unsub, ref, afterReceiving})
  def flush(self, timeout \\ :infinity),
    do: GenServer.call(self, {:cmd, nil, true}, timeout)
  def stop(self, timeout \\ :infinity) do
    flush(self, timeout)
    GenServer.stop(self)
  end
end

