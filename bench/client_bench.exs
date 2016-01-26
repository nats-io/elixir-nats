defmodule ClientBench do
  use Benchfella
  alias Nats.Client

  # Test how many messages of a given size we can publish
  # in a given time frame...
  
  @mesg_sizes [0, 16, 32, 64, 128, 256, 512, 1024, 4096, 8192]
  
  before_each_bench _ do
    subject = "subject"
    {:ok, conn} = Client.start_link
    mesgs_by_size =
      Enum.reduce(@mesg_sizes, %{},
        fn x, acc -> Map.put(acc, x, make_mesg(x)) end)
    {:ok, {conn, subject, mesgs_by_size}}
  end

  # make a message of the given size...
  defp make_mesg(size) do
    template = "Hello NATS world!"
    template_size = String.length(template)
    mesg = String.duplicate(template, div(size, template_size))
    rem = rem(size, template_size)
    if rem, do: mesg = mesg <> String.slice(template, 0, rem)
    mesg
  end

  # trickery with macros...
  Enum.each(@mesg_sizes, fn size -> 
    @msg_size size
    bench "pub test size #{size}", [size: @msg_size] do
      m = elem(bench_context, 2)[size]
      Client.pub(elem(bench_context, 0),
                 elem(bench_context, 1),
                 m)
    end
  end)
end
