defmodule PiMonitor.Worker do
  use GenServer
  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(_opts) do
    Logger.configure(level: :all)
    {:ok, _tref} = :timer.send_interval(1000, :ping)
    Logger.info("#{__MODULE__} initialized")
    {:ok, []}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_cast({:exit_status, id, 0, end_time}, state) do
    PiMonitor.Storage.update(id, end_time)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:exit_status, id, _, _}, state) do
    PiMonitor.Storage.update(id, :failed)
    {:noreply, state}
  end

  @impl true
  def handle_info(:ping, state) do
    id = PiMonitor.Storage.add(:erlang.system_time())

    Task.start(fn ->
      port =
        :erlang.open_port({:spawn_executable, "/bin/ping"}, [
          {:args, ["-c1", "-W 600", "8.8.8.8"]},
          :exit_status
        ])

      receive do
        {^port, {:exit_status, exit_code}} ->
          finish(id, exit_code, :erlang.system_time())
      end
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info(msg, state) do
    Logger.warn("unexpected message #{inspect(msg)}")
    {:noreply, state}
  end

  def finish(id, exit_code, end_time) do
    GenServer.cast(__MODULE__, {:exit_status, id, exit_code, end_time})
  end

  def get_stats() do
    GenServer.call(__MODULE__, :get_stats)
  end
end
