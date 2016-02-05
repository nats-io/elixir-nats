# Copyright 2016 Apcera Inc. All rights reserved.
defmodule Bench do
  alias Nats.Client

  @moduledoc """
  Simple benchmark for NATS client operations. Far from perfect :-( and 
  very ugly!

  ## Overview
  This module's goals is to measure the amount of time it takes to perfom
  various NATS verbs/operations for a given message size N.

  Our operations here are pub, pubsub and req/rep.

  From a model perspective we wish to define:
  - throughout in bytes/memory per second (or some time frame)
  - throughout in messages per second
  - latency for pub/sub and req/reply operations
  """
  
  # Test how many messages of a given size we can publish
  # in a given time frame...
  @mesg_sizes [0, 8, 512, 1024, 4096, 8192]
  @sync_point 32768

  # make a message of the given size...
  defp make_mesg(size) do
    template = "Hello NATS world!"
    template_size = String.length(template)
    String.duplicate(template, div(size, template_size)) <>
      String.slice(template, 0, rem(size, template_size))
  end

  defp receiver_loop(so_far, so_far, _, sync_pid) do
#    IO.puts "receiver_loop: got expected messages, exiting..."
    send sync_pid, {:done, so_far}
  end
  defp receiver_loop(so_far, expected, sync, sync_pid) do
    receive do
      # make sure its a nats message
      {:msg, _, _, _, _ } ->
        so_far = so_far + 1
        if rem(so_far, sync) == 0, do: send sync_pid, {:received, so_far}
        receiver_loop(so_far, expected, sync, sync_pid)
      :stop_recv ->
        # IO.puts "receiver_loop: stopping #{expected}"
        :ok
    after 6000 ->
        IO.puts "receiver_loop: timeout"
        receiver_loop(so_far, expected, sync, sync_pid)
    end
  end
  defp receiver do
    receive do
      {:start, expected, sync, sync_pid} ->
        send sync_pid, :ok
        #IO.puts "starting receiver..."
        receiver_loop(0, expected, sync, sync_pid)
      :stop_recv ->
        #IO.puts "receiver: stopping (never started...)"
        :ok
    after 1000 -> IO.puts "receiver: timeout"
    end
  end
  def setup(size, num_msgs) do
    subject = "BS"
    {:ok, conn} = Client.start_link
    pid = spawn_link(&receiver/0)
    send pid, {:start, num_msgs, @sync_point, self()}
#    on_exit fn -> 
#      IO.puts "done running..."
#      send pid, :stop_recv
#      :ok
#    end
    {:ok, %{ receiver: pid, mesg: make_mesg(size),
             conn: conn, num_msgs: num_msgs,
             subject: subject <> to_string(size) }}
  end

  def pub_bench(conn, receiver, subject, _size, mesg, num_msgs) do
    send receiver, :stop_recv
    before = get_mem(true)
    {t, :ok} = :timer.tc(fn -> do_pub(conn, subject, mesg, num_msgs, true)
    end)
    after_mem = get_mem()
    after_gc = get_mem(true)
    used = sub_mem(after_gc, before)
    used_pre_gc = sub_mem(after_mem, before)
    mem_stats = %{ used: used, used_pre_gc: used_pre_gc }
    {t, num_msgs, mem_stats}
  end
  def sub_bench(conn, receiver, subject, _size, _mesg, num_msgs) do
    send receiver, :stop_recv
    before = get_mem(true)
    {t, :ok} = :timer.tc(fn -> do_sub(conn, subject, receiver, num_msgs, true)
    end)
    after_mem = get_mem()
    after_gc = get_mem(true)
    used = sub_mem(after_gc, before)
    used_pre_gc = sub_mem(after_mem, before)
    mem_stats = %{ used: used, used_pre_gc: used_pre_gc }
    {t, num_msgs, mem_stats}
  end
  defp do_sub(_, _, _, 0, false), do: :ok
  defp do_sub(con, _, _, 0, true), do: Client.flush(con, :infinity)
  defp do_sub(con, sub, r, n, flush) do
    {:ok, _ref} = Client.sub(con, r, sub <> to_string(n))
    do_sub(con, sub, r, n-1, flush)
  end
  def pubasync_bench(conn, receiver, subject, _size, mesg, num_msgs) do
    send receiver, :stop_recv
    before = get_mem(true)
    {t, :ok} = :timer.tc(fn -> do_pub(conn, subject, mesg, num_msgs, false) end)
    after_mem = get_mem()
    after_gc = get_mem(true)
    used = sub_mem(after_gc, before)
    used_pre_gc = sub_mem(after_mem, before)
    mem_stats = %{ used: used, used_pre_gc: used_pre_gc }
    {t, num_msgs, mem_stats}
  end
  defp do_pub(_, _, _, 0, false), do: :ok
  defp do_pub(con, _, _, 0, true), do: Client.flush(con, :infinity)
  defp do_pub(con, sub, what, n, flush) do
    :ok = Client.pub(con, sub, what)
    do_pub(con, sub, what, n-1, flush)
  end

  def time_start(), do: :erlang.timestamp()
  def time_delta(now, prev), do: :erlang.now_diff(now, prev)
  def get_mem(gc_first \\ false) do
    if gc_first, do: :erlang.garbage_collect()
    pinfo = for pid <- :erlang.processes(),
      do: :erlang.process_info(pid, :memory)
    sys = :erlang.memory()
    mapped = Enum.map(pinfo, fn v ->
      case v do
        {:memory, how_much} -> how_much
        _other -> 0
      end
      end)
    tot_mem = Enum.reduce(mapped, &+/2)
    %{memory: tot_mem, sys_bin: sys[:binary], sys_atom: sys[:atom]}
  end
  def sub_mem(now = %{}, prev = %{}) do
    %{ memory: now.memory - prev.memory,
       sys_bin: now.sys_bin - prev.sys_bin,
       sys_atom: now.sys_atom - prev.sys_atom}
  end
  
  def pubsub_bench(conn, receiver, subject, _size, mesg, num_msgs) do
    {:ok, v} = Client.start_link
#    v = conn
    {:ok, ref} = Client.sub(v, receiver, subject)
    :ok = Client.flush(v, :infinity)
    # wait till our receiver to start...

    before = get_mem(true)
    receive do :ok -> :ok end
    {t, :ok } = :timer.tc(fn ->
      do_pubsub(conn, subject, mesg, 0, num_msgs, 0)
    end)
    after_mem = get_mem()
    after_gc = get_mem(true)
    used = sub_mem(after_gc, before)
    used_pre_gc = sub_mem(after_mem, before)
    mem_stats = %{ used: used, used_pre_gc: used_pre_gc }
    :ok = Client.unsub(v, ref)
    :ok = GenServer.stop(v)
    {t, num_msgs, mem_stats}
  end

  defp drain(conn) do
    receive do
      {:done, _count} ->
#        IO.puts "drain #{count}"
        :ok
      _ -> drain(conn)
    after 5000 ->
        IO.puts "timeout draining"
        drain(conn)
    end
  end
  
  defp do_pubsub(conn, _, _, so_far, so_far, _) do
    Client.flush(conn)
    drain(conn)
  end
  defp do_pubsub(conn, sub, what, so_far, n, last_update) do
    so_far = so_far + 1
    :ok = Client.pub(conn, sub, what)
    if rem(so_far, @sync_point) == 0 do
      receive do
        {:received, x} ->
#          IO.puts x
          last_update = x
      end
    end
    if (so_far - last_update) == @sync_point do
      :erlang.yield() # .sleep(10)
    end
    do_pubsub(conn, sub, what, so_far, n, last_update)
  end
  defp teardown(ctx) do
#    IO.puts"stopping..."
    :ok = GenServer.stop(ctx.conn)
  end
  def run_test(_, test, size, num_msgs) do
    case setup(size, num_msgs) do
      {:ok, sub_ctx} ->
#        IO.puts "context: #{inspect Map.delete(sub_ctx, :mesg)}"
        res = test.(sub_ctx.conn, sub_ctx.receiver, sub_ctx.subject, size,
                    sub_ctx.mesg, sub_ctx.num_msgs)
        teardown(sub_ctx)
        res
      other ->
        other
    end
  end
  def predict_test(nruns, duration, name, test, size) do
#     IO.puts  "RUNNING: #{name}: N=#{inspect nruns} T=#{inspect duration} S=#{size}"
     res = run_test(name, test, size, nruns)
     case res do
       {micros, ^nruns, _mem} when micros < duration ->
         per_n = micros / nruns
         new_runs = if per_n == 0, do: nruns * 10, else: duration / per_n
         new_runs = trunc(min(nruns * 1.66 + (3.33*(micros / duration)),
                              new_runs))
         [res|predict_test(new_runs, duration, name, test, size)]
       _x -> [res]
     end
  end

  def predict_test(duration, name, test, size) do
     old_predicton = 10000
     duration = s2mu(duration)
     predict_test(old_predicton, duration, name, test, size)
  end
  def run_tests (duration) do
    run_tests(duration,
              [
                {"PUB", &pub_bench/6, true},
                {"PUB-SUB", &pubsub_bench/6, true},
                {"PUB-ASYNC", &pubasync_bench/6, true},
                {"SUB", &sub_bench/6, false}
              ],
              @mesg_sizes)
  end
  defp summarize(results) do
    true_res = last(results)
#    IO.inspect results
    per_n = fn { micros, count, _ } -> count / micros end
    per_n_red = Enum.map(results, per_n)
    stats = fn en ->
      cnt = Enum.count(en)
      mi = Enum.reduce(en, &min/2)
      ma = Enum.reduce(en, &max/2)
      sum = Enum.reduce(en, &+/2)
      mean = sum / cnt
      { cnt, mi, ma, sum, mean }
    end
    rst = stats.(per_n_red)
    { cnt, _mi, _ma, _sum, mean } = rst
    diffs = Enum.map(per_n_red, &:math.pow(&1 - mean, 2))
    variances = stats.(diffs)
    { _scnt, _smi, _sma, _ssu, variance } = variances
    sdev = :math.sqrt(variance)
    std_err = sdev / :math.sqrt(cnt)
    zs = %{99 => 1.28,
           98 => 1.645,
           95 => 1.96,
           90 => 2.33,
           80 => 2.58}
    v = per_n.(true_res)
    # IO.inspect "per n ->"
    # IO.puts "    #{inspect per_n_red}"
    # IO.puts "    stats=#{inspect rst}"
    # IO.puts "    vars=#{inspect variances}"
    # IO.puts "    N=#{cnt} MIN=#{ft mi} MAX=#{ft ma}"
    # IO.puts "    R=#{ft per_n.(true_res)}"
    # IO.puts "    μ=#{ft mean}"
    # IO.puts "    v=#{ft variance, 4} σ=#{ft sdev, 4}"
    # IO.puts "    z=#{ft std_err}"
    sigs = Enum.filter_map(zs, fn {_, zv} ->
      abs(v - mean) <= (std_err * zv)
    end, fn {k, _} -> to_string(k) end)
#    IO.puts "     sigs=#{inspect sigs}"
    List.to_tuple(Tuple.to_list(true_res) ++ [sigs])
  end
  defp last([h]), do: h
  defp last([_|t]), do: last(t)
  
  def run_tests(duration, tests, mesg_sizes) do
    Enum.map(tests, fn {name, test, sized?} ->
      %{name: name, sized: sized?,
        results: if sized? do
          Enum.map(mesg_sizes,
            fn sz ->
              res = predict_test(duration, name, test, sz)
              {sz, summarize(res)}
            end)
          else
            res = predict_test(duration, name, test, 0)
            [{0, summarize(res)}]
        end
        }
    end)
  end

  def format_now do

    local = :calendar.local_time()
    {{yyyy,mm,dd},{hour,min,sec}} = local
    res = :io_lib.
      format("~4..0B-~2..0B-~2..0B ~2..0B:~2..0B:~2..0B",
		         [yyyy, mm, dd, hour, min, sec])
    res = IO.chardata_to_string(res)
    utc = :calendar.universal_time()
    offs = round ((:calendar.datetime_to_gregorian_seconds(local) -
                   :calendar.datetime_to_gregorian_seconds(utc)) / 60)
    if offs != 0 do
      suf = if offs < 0, do: (offs = -offs; ?-), else: ?+
      res = res <>
       IO.chardata_to_string(:io_lib.format("~c~2..0B", [suf, div(offs, 60)]))
      mins = rem(offs, 60)
      if mins,
        do: res = res <> IO.chardata_to_string(:io_lib.format(":~2..0B",
                                                            [mins]))
    else
      res = res <> "Z"
    end
    res
  end
  
  def ft(t, ndigs \\ 2) do
    Float.round(t / 1.0, ndigs)
  end
  def mu2s(t), do: t / 1_000_000
  def s2mu(t), do: t * 1_000_000
  defp humanize_bytes(b) do
    units = 1_000_000
    b = b / units
    "#{ft b}mb"
  end
  def through(sized?, chunks, msg_size, total_micros) do
    msg_per_t = chunks / mu2s(total_micros)
    byte_per_t = (chunks * msg_size) / mu2s(total_micros)
    t_per_op = if chunks != 0, do: total_micros / chunks, else: 0
    bps = (sized? && " #{humanize_bytes byte_per_t}/sec") || ""
    "#{ft msg_per_t}msg/sec #{ft t_per_op}μs/op #{bps}"
  end
end

default_duration = 5.0
{tot, by_test} = :timer.tc(fn -> Bench.run_tests(default_duration) end)
IO.puts "## Begin Bench"
IO.puts "Run-on: #{Bench.format_now}"
IO.puts "Duration-seconds: #{Bench.ft Bench.mu2s tot}"
Enum.each(by_test, fn %{name: name, sized: sized?, results: results}  ->
  Enum.map(results, fn x ->
    {size, {time, num_chunks, mem, extras}} = x
    IO.puts("#{name}#{(sized? && "-" <> to_string(size)) || ""}: T=#{Bench.ft Bench.mu2s time}: N=#{num_chunks} #{Bench.through(sized?, num_chunks, size, time)}")
    conf = if Enum.count(extras) != 0,
    do: Enum.map(extras, &(&1 <> "% ")),
    else: "(NONE)"
    IO.puts("## Confidence: #{conf}")
    IO.puts "## mem=#{inspect mem.used} gcmem=#{inspect mem.used_pre_gc}"
    {size, time}
  end)
#  IO.puts "results for #{name}: #{inspect xform}"
end)

