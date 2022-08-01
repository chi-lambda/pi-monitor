defmodule PiMonitor.Telegram.Notifier do
  use GenServer
  require Logger

  @min_gap 3_600_000
  @max_gap 6 * 60 * 60 * 1000
  @threshold 2

  @impl true
  def init(:ok) do
    {:ok, tref} = :timer.send_interval(60000, :send_notification)
    last_call = :erlang.system_time(:milli_seconds)
    {:ok, {tref, last_call}}
  end

  @impl true
  def handle_cast(:test_notification, state) do
    PiMonitor.Telegram.Api.send_message('This is a test message')

    {:noreply, state}
  end

  def handle_cast(:send_notification, state) do
    %{pending: _, failed: failed, received: received} =
      PiMonitor.Storage.get_grouped(PiMonitor.Storage, 3600)

    failure_rate = failed / max(received + failed, 1) * 100
    message_text = "Received: #{received}, Failed: #{failed}, Failure rate: #{failure_rate}%"
    {:ok, _} = PiMonitor.Telegram.Api.send_message(message_text)
    {:noreply, state}
  end

  def handle_cast({:process_message, "/ping"}, state) do
    handle_cast(:send_notification, state)
  end

  def handle_cast({:process_message, "/temp"}, state) do
    case File.read("/sys/class/thermal/thermal_zone0/temp") do
      {:ok, content} ->
        temp = :erlang.binary_to_integer(String.trim(content))
        PiMonitor.Telegram.Api.send_message("#{temp / 1000}°C")

      {:error, _} ->
        PiMonitor.Telegram.Api.send_message("Can't read temperature")
    end

    {:noreply, state}
  end

  def handle_cast({:process_message, "/ip"}, state) do
    case HTTPoison.get("https://ip4.me/api/") do
      {:ok, %{body: body}} ->
        fields = String.split(body, ",")
        PiMonitor.Telegram.Api.send_message(hd(tl(fields)))

      _ ->
        PiMonitor.Telegram.Api.send_message("Failed to get IP address.")
    end

    {:noreply, state}
  end

  def handle_cast({:process_message, _}, state) do
    PiMonitor.Telegram.Api.send_message("Whatcha talkin' 'bout, Willis?")
    {:noreply, state}
  end

  @impl true
  def handle_info(:send_notification, {tref, last_call} = state) do
    %{pending: _, failed: failed, received: received} =
      PiMonitor.Storage.get_grouped(PiMonitor.Storage, 3600)

    failure_rate = failed / max(received + failed, 1) * 100
    now = :erlang.system_time(:milli_seconds)

    since = now - last_call

    if since > @max_gap or (failure_rate > @threshold and since > @min_gap) do
      message_text = "Received: #{received}, Failed: #{failed}, Failure rate: #{failure_rate}%"

      case PiMonitor.Telegram.Api.send_message(message_text) do
        {:ok, _} -> {:noreply, {tref, now}}
        _ -> {:noreply, state}
      end

      {:noreply, {tref, now}}
    else
      {:noreply, state}
    end
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end

  def test_notification() do
    GenServer.cast(__MODULE__, :test_notification)
  end

  def send_notification() do
    GenServer.cast(__MODULE__, :send_notification)
  end

  def process_message(message) do
    GenServer.cast(__MODULE__, {:process_message, message})
  end
end
