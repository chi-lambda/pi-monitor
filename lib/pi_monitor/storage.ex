defmodule PiMonitor.Storage do
  use GenServer
  require Logger
  require Record

  Record.defrecord(:ping_storage,
    counter: :undefined,
    start_time: :undefined,
    end_time: :undefined
  )

  @impl true
  def init(:ok) do
    :ok = create_schema()
    Application.start(:mnesia)
    :ok = create_table()
    counter = last() + 1
    {:ok, %{counter: counter}}
  end

  @impl true
  def handle_call({:add, start_time}, _from, %{counter: counter} = state) do
    {:atomic, :ok} =
      :mnesia.transaction(fn ->
        :ok =
          :mnesia.write(
            ping_storage(counter: counter, start_time: start_time, end_time: :pending)
          )
      end)

    cleanup(counter, 86400)
    {:reply, counter, %{state | counter: counter + 1}}
  end

  @impl true
  def handle_call({:update, key, end_time}, _from, state) do
    {:atomic, :ok} =
      :mnesia.transaction(fn ->
        [ping_storage(counter: ^key, start_time: start_time)] =
          :mnesia.wread({:ping_storage, key})

        :ok =
          :mnesia.write(
            :ping_storage,
            ping_storage(counter: key, start_time: start_time, end_time: end_time),
            :write
          )
      end)

    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:get, age}, _from, %{counter: counter} = state) do
    # fn {c, _, end_time} when c >= counter - age -> end_time end
    {:atomic, result} =
      :mnesia.transaction(fn ->
        :mnesia.select(:ping_storage, [
          {{:ping_storage, :"$1", :_, :"$2"}, [{:>=, :"$1", counter - age}], [:"$2"]}
        ])
      end)

    {:reply, result, state}
  end

  defp cleanup(counter, age) do
    :mnesia.transaction(fn ->
      # fn {c, _} when c < counter - age -> {:ping_storage, :"$1"} end
      entities =
        :mnesia.select(:ping_storage, [
          {{:"$1", :_, :_}, [{:<, :"$1", counter - age}], [{:ping_storage, :"$1"}]}
        ])

      :lists.foreach(fn entity -> :mnesia.delete(entity) end, entities)
    end)
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

  defp create_schema do
    n = node()

    case :mnesia.create_schema([n]) do
      :ok -> :ok
      {:error, {^n, {:already_exists, ^n}}} -> :ok
      x -> x
    end
  end

  defp create_table do
    case :mnesia.create_table(:ping_storage,
           type: :ordered_set,
           disc_copies: [node()],
           attributes: [:counter, :start_time, :end_time]
         ) do
      {:atomic, :ok} -> :ok
      {:aborted, {:already_exists, :ping_storage}} -> :ok
    end

    :mnesia.wait_for_tables([:ping_storage], :infinity)
  end

  defp last() do
    case :mnesia.transaction(fn -> :mnesia.last(:ping_storage) end) do
      {:atomic, :"$end_of_table"} -> 0
      {:atomic, x} -> x
    end
  end
end
