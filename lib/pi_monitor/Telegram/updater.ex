defmodule PiMonitor.Telegram.Updater do
  use GenServer
  require Logger

  @timeout 10

  @impl true
  def init(:ok) do
    Task.Supervisor.async_nolink(PiMonitor.Task.Supervisor, fn ->
      PiMonitor.Telegram.Api.get_updates(0, @timeout)
    end)

    {:ok, %{offset: 0}}
  end

  @impl true
  def handle_info({ref, {:ok, %{body: body}}}, %{offset: offset} = state) do
    Process.demonitor(ref, [:flush])

    case Jason.decode!(body) do
      %{"result" => result} ->
        if Enum.count(result) > 0 do
          messages =
            Enum.filter(result, fn msg -> Map.has_key?(msg, "message") end)
            |> Enum.map(fn msg -> msg["message"]["text"] end)

          update_ids = Enum.map(result, fn msg -> msg["update_id"] end)
          new_offset = Enum.max(update_ids) + 1
          :lists.foreach(fn msg -> PiMonitor.Telegram.Notifier.process_message(msg) end, messages)

          Task.Supervisor.async_nolink(PiMonitor.Task.Supervisor, fn ->
            PiMonitor.Telegram.Api.get_updates(new_offset, @timeout)
          end)

          Logger.info("Got #{Enum.count(result)} new messages: '#{Enum.join(messages, "','")}'.")
          {:noreply, %{state | offset: new_offset}}
        else
          Task.Supervisor.async_nolink(PiMonitor.Task.Supervisor, fn ->
            PiMonitor.Telegram.Api.get_updates(offset, @timeout)
          end)

          {:noreply, state}
        end

      %{"ok" => false, "description" => description, "error_code" => error_code} ->
        Logger.warn("Error calling getUpdates: #{error_code} #{description}")
    end
  end

  def handle_info({ref, result}, %{offset: offset} = state) when is_reference(ref) do
    Logger.warn("Received failed response: #{inspect(result)}")
    Process.demonitor(ref, [:flush])

    Task.Supervisor.async_nolink(PiMonitor.Task.Supervisor, fn ->
      PiMonitor.Telegram.Api.get_updates(offset, @timeout)
    end)

    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, _, _, _reason}, %{offset: offset} = state) do
    Task.Supervisor.async_nolink(PiMonitor.Task.Supervisor, fn ->
      PiMonitor.Telegram.Api.get_updates(offset, @timeout)
    end)

    {:noreply, state}
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end
end
