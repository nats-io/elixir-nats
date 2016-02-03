# Copyright 2016 Apcera Inc. All rights reserved.
defmodule Bench do
  alias Nats.Client

  @moduledoc """
  Simple benchmark for NATS client operations. Far from perfect :-(

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
  # how many messages we send/receive in one bench run for a given size,
  # this should be at least a couple of seconds of activity... not a perfect
  @num_chunks 100_000
  @sync_point 10000

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
  def setup_all do
    subject = "BS"
    {:ok, conn} = Client.start_link
    {:ok, %{conn: conn, subject: subject }}
  end
  def setup(context, size) do
    pid = spawn_link(&receiver/0)
    send pid, {:start, @num_chunks, @sync_point, self()}
#    on_exit fn -> 
#      IO.puts "done running..."
#      send pid, :stop_recv
#      :ok
#    end
    {:ok, %{ receiver: pid, mesg: make_mesg(size),
             subject: context.subject <> to_string(size) }}
  end

  def pub_bench(conn, receiver, subject, _size, mesg) do
    send receiver, :stop_recv
    :timer.tc(fn -> do_pub(conn, subject, mesg, @num_chunks) end)
  end
  defp do_pub(con, _, _, 0), do: Client.flush(con, :infinity)
  defp do_pub(con, sub, what, n) do
    :ok = Client.pub(con, sub, what)
    do_pub(con, sub, what, n-1)
  end

  def pubsub_bench(conn, receiver, subject, _size, mesg) do
    {:ok, ref} = Client.sub(conn, receiver, subject)
    # wait till our receiver to start...
    receive do :ok -> :ok end
    res = :timer.tc(fn -> do_pubsub(conn, subject, mesg, 0, @num_chunks) end)
    Client.unsub(conn, ref)
    res
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
  
  defp do_pubsub(conn, _, _, so_far, so_far) do
    Client.flush(conn)
    drain(conn)
  end
  defp do_pubsub(conn, sub, what, so_far, n) do
    so_far = so_far + 1
    :ok = Client.pub(conn, sub, what)
    if rem(so_far, @sync_point) == 0 do
      receive do
        _x ->
          #IO.puts "sync #{inspect _x}"
          :ok
      end
    end
    do_pubsub(conn, sub, what, so_far, n)
  end
  def run_test(name, test, size, ctx) do
    ctx = Map.put(ctx, :name, name)
    ctx = Map.put(ctx, :size, size)
    case setup(ctx, size) do
      {:ok, sub_ctx} ->
        ctx = Map.merge(ctx, sub_ctx)
#        IO.puts "context: #{inspect Map.delete(ctx, :mesg)}"
        test.(ctx.conn, ctx.receiver, ctx.subject, size, ctx.mesg)
      other ->
        other
    end
  end
  def run_tests(tests \\ [{"PUB", &pub_bench/5},
                          {"PUB-SUB", &pubsub_bench/5}]) do
    ctx = setup_all
    case ctx do
      {:ok, vars } ->
        results = Enum.map(tests, fn {name, test} ->
          %{name: name,
            results: Enum.map(@mesg_sizes,
               fn sz -> {sz, run_test(name, test, sz, vars)} end)
           }
        end)
#        IO.puts "Results -> #{inspect results}"
        {@num_chunks, results}
      other ->
        IO.puts "unable to start test: #{inspect other}"
        other
    end
  end
  @time_units 1_000_000
  def ft(t) do
    Float.round(t / 1.0, 4)
  end
  defp humanize_bytes(b) do
    units = 1_000_000
    b = b / units
    "#{ft b}mb/s"
  end
  def through(chunks, msg_size, total_micros) do
    msg_per_t = chunks / (total_micros  / @time_units)
    byte_per_t = (chunks * msg_size) / (total_micros  / @time_units)
    t_per_op = total_micros / chunks
    "msg/sec=#{ft msg_per_t} bytes/ps=#{humanize_bytes byte_per_t} micos/op=#{ft t_per_op}"
  end
end

{tot, {num_chunks, by_test}} = :timer.tc(&(Bench.run_tests)/0)
IO.puts "Duration: #{Bench.ft tot / 1_000_000}"
IO.puts "Messages: #{num_chunks}"
Enum.each(by_test, fn %{name: name, results: results}  ->
  _xform = Enum.map(results, fn {size, {time, :ok}} -> 
    IO.puts("#{name}-#{size}: duration #{Bench.ft time / 1_000_000}: #{Bench.through(num_chunks, size, time)}")
    {size, time}
  end)
#  IO.puts "results for #{name}: #{inspect xform}"
end)

