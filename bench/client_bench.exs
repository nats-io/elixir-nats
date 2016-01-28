# Copyright 2016 Apcera Inc. All rights reserved.

defmodule ClientBench do
  use Benchfella
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
  @num_chunks 4096
  
  setup_all do
    subject = "subject"
    fake_subject = "fake_subject"
    {:ok, conn} = Client.start_link
    mesgs_by_size =
      Enum.reduce(@mesg_sizes, %{},
        fn x, acc -> Map.put(acc, x, make_mesg(x)) end)
    {:ok, {conn, subject, fake_subject, mesgs_by_size}}
  end

  # make a message of the given size...
  defp make_mesg(size) do
    template = "Hello NATS world!"
    template_size = String.length(template)
    String.duplicate(template, div(size, template_size)) <>
      String.slice(template, 0, rem(size, template_size))
  end

  # trickery and pain... with macros...
  Enum.each(@mesg_sizes, fn size -> 
    @msg_size size
    @num_pub_chunks @num_chunks
    bench "PUB #{@num_pub_chunks} of size #{@msg_size}",
      [con: elem(bench_context, 0),
       sub: elem(bench_context, 2) <> "_p_#{@msg_size}",
       what: elem(bench_context, 3)[@msg_size]] do
      do_pub(con, sub, what, @num_pub_chunks)
    end

    defp do_pub(_, _, _, 0), do: :ok
    defp do_pub(con, sub, what, n) do
        :ok = Client.pub(con, sub, what)
        do_pub(con, sub, what, n-1)
    end
  end)

  Enum.each(@mesg_sizes, fn size -> 
    @msg_size size
    @num_pubsub_chunks @num_chunks
    bench "PUB-SUB #{@num_pubsub_chunks} of size #{@msg_size}",
      [con: elem(bench_context, 0),
       sub: elem(bench_context, 1) <> "_ps_#{@msg_size}",
       what: elem(bench_context, 3)[@msg_size]] do
      # ideally done once, lazy ;-)
      Client.subscribe(con, self(), sub)
      do_pubsub(con, sub, what, @num_pubsub_chunks)
    end
    defp do_pubsub(_, _, _, 0), do: :ok
    defp do_pubsub(con, sub, what, n) do
      Client.pub(con, sub, what)
      new_n = n
      receive do
        {:msg, ^sub, nil, ^what } -> new_n = n - 1
      after 500 -> IO.puts "timeout in test..."
      end
      do_pubsub(con, sub, what, new_n)
    end
  end)
end
