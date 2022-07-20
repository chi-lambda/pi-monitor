defmodule PiMonitor.Storage do
  use GenServer
  require Logger

  @impl true
  def init(:ok) do
    table = :ets.new(:ping_storage, [:ordered_set])
    {:ok, {1, table}}
  end

  @impl true
  def handle_call({:add, start_time}, _from, {counter, table} = state) do
    :ets.insert(table, {counter, start_time, :pending})
    cleanup(state, 86400)
    {:reply, counter, {counter + 1, table}}
  end

  @impl true
  def handle_call({:update, key, end_time}, _from, {counter, table}) do
    :ets.update_element(table, key, {3, end_time})
    {:reply, :ok, {counter, table}}
  end

  @impl true
  def handle_call({:get, age}, _from, {counter, table} = state) do
    # fn {c, _, end_time} when c >= counter - age -> end_time end
    result = :ets.select(table, [{{:"$1", :_, :"$2"}, [{:>=, :"$1", counter - age}], [:"$2"]}])

    {:reply, result, state}
  end

  defp cleanup({counter, table}, age) do
    :ets.select_delete(
      table,
      # fn {c, _} when c < counter - age -> true end
      [{{:"$1", :_, :_}, [{:<, :"$1", counter - age}], [true]}]
    )
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def add(start_time) do
    GenServer.call(__MODULE__, {:add, start_time})
  end

  def update(id, end_time) do
    GenServer.call(__MODULE__, {:update, id, end_time})
  end

  def get(server, age) do
    GenServer.call(server, {:get, age})
  end

  def get_grouped(server, age) do
    stats = get(server, age)

    List.foldl(stats, %{pending: 0, failed: 0, received: 0}, fn status, m ->
      Map.update!(m, simplify(status), fn x -> x + 1 end)
    end)
  end

  defp simplify(:pending) do
    :pending
  end

  defp simplify(:failed) do
    :failed
  end

  defp simplify(_) do
    :received
  end
end
