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
    Task.start(fn ->
      {:atomic, :ok} =
        :mnesia.transaction(fn ->
          :ok =
            :mnesia.write(
              ping_storage(counter: counter, start_time: start_time, end_time: :pending)
            )
        end)
      end)

    # cleanup(counter, 86400)
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

  def get(age) do
    last = :mnesia.dirty_last(:ping_storage)
    :mnesia.dirty_select(:ping_storage, [
      {{:ping_storage, :"$1", :"$2", :"$3"}, [{:>=, :"$1", last - age + 1}], [{{:'$2',:'$3'}}]}
    ])
  end

  def get_by_timestamp(from, to) do
    pings = :mnesia.dirty_select(:ping_storage, [
      {{:ping_storage, :_, :"$1", :"$2"}, [{:andalso, {:>=, :"$1", from}, {:<, :"$1", to}}],
       [{{:"$1", :"$2"}}]}
    ])
    successful_pings = Enum.filter(pings, fn({_, end_time}) -> is_number(end_time) end)
    failed_pings = Enum.filter(pings, fn({_, end_time}) -> end_time == :failed end)
    pending_pings = Enum.filter(pings, fn({_, end_time}) -> end_time == :pending end)
    now = :erlang.system_time()
    %{
      successful: Enum.map(medianize(successful_pings, 10), fn ({start_time, duration}) ->
        %{x: start_time / 1000000, y: duration / 1000000000}
      end),
      failed: Enum.map(failed_pings, fn({start_time, _}) -> %{x: start_time / 1000000, y: 0} end),
      pending: Enum.map(pending_pings, fn({start_time, _}) -> %{x: start_time / 1000000, y: 0} end)
    }
  end

  def get_as_json_averaged(age, stride) do
    pings = get(age)

    Enum.map(average(pings, max(1, stride)), fn {start_time, duration} ->
      %{start_time: start_time, duration: duration}
    end)
  end

  def get_as_json_medianized(age, stride) do
    pings = get(age)

    Enum.map(medianize(pings, max(1, stride)), fn {start_time, duration} ->
      %{start_time: start_time, duration: duration}
    end)
  end

  defp average(list, stride) do
    chunked = Enum.chunk_every(Enum.filter(list, fn({_, end_time}) -> is_number(end_time) end), stride)
    Enum.map(chunked, fn([{start_time, _}|_] = chunk) -> {start_time, Enum.sum(Enum.map(chunk, &calculate_duration/1)) / stride} end)
  end

  defp medianize(list, stride) do
    chunked = Enum.chunk_every(Enum.filter(list, fn({_, end_time}) -> is_number(end_time) end), stride, stride, :discard)
    Enum.map(chunked, fn([{start_time, _}|_] = chunk) -> {start_time, Enum.at(Enum.sort(Enum.map(chunk, &calculate_duration/1)), div(stride, 2))} end)
  end

  defp calculate_duration({_, :failed}) do
    0
  end

  defp calculate_duration({_, :pending}) do
    0
  end

  defp calculate_duration({start_time, end_time}) do
    end_time - start_time
  end

  def get_grouped(age) do
    stats = get(age)

    List.foldl(stats, %{pending: 0, failed: 0, received: 0}, fn {_, status}, m ->
      Map.update!(m, simplify(status), fn x -> x + 1 end)
    end)
  end

  def dump_to_textfile(filename, age) do
    last = :mnesia.dirty_last(:ping_storage)
    first = last - age
    {:ok, file} = File.open(filename, [:write])
    spawn(fn -> dump_to_textfile_loop(file, first) end)
  end

  defp dump_to_textfile_loop(file, i) do
    if i <= :mnesia.dirty_last(:ping_storage) do
      rec = :mnesia.dirty_read(:ping_storage, i)
      IO.write(file, :io_lib.format('~p~n', [rec]))
      dump_to_textfile_loop(file, i + 1)
    else
      :ok = File.close(file)
    end
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
