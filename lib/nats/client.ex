defmodule Nats.Client do
  use GenServer
  require Logger

  @default_host "127.0.0.1"
  @default_port 4222
  @default_timeout 5000

  @default_opts %{ tls_required: false,
                   auth: %{}, # "user" => "user", "pass" => "pass"},
                   verbose: false,
                   timeout: @default_timeout,
                   host: @default_host, port: @default_port,
                   socket_opts: [:binary, active: true],
                   ssl_opts: []}
  @start_state %{ conn: nil, opts: %{}, status: :starting, why: nil,
                  subs_by_pid: %{},
                  subs_by_sid: %{}}

  def start_link(opts \\ @default_opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
#    IO.puts "init! #{inspect(opts)}"
    state = @start_state
    opts = Map.merge(state.opts, opts)
    parent = self()
    case Nats.Connection.start_link(parent, opts) do
      {:ok, x}  when is_pid(x) ->
        state = %{state | conn: x, status: :connecting, opts: opts}
      other -> {:error, "unable to start connection link", other}
    end
#    IO.puts("state -> #{inspect(state)}")
    {:ok, state, state.opts.timeout}
  end

  def handle_info(_what, state) do
#    IO.puts "handle_info #{inspect(what)}"
    {:noreply, state}
  end
  def handle_cast(_command, state) do
#    IO.puts "handle_cast #{inspect(command)}"
    {:noreply, state}
  end
  def handle_call(request, _from, state) do
#    IO.puts "handle_call #{inspect(request)}"
    send state.conn, {:command, request}
    {:reply, :ok, state}
  end

  def pub(self, subject, what) do pub(self, subject, nil, what) end
  def pub(self, subject, reply, what) do
    GenServer.call(self, {:pub, subject, reply, what})
  end

  def subscribe(self, subject), do: subscribe(self, subject, nil)
  def subscribe(self, subject, queue),
    do: GenServer.call(self, {:sub, subject, queue, subject})
end
