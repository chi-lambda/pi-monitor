defmodule PiMonitor do
  require Logger
  @spec get_pretty_stats :: binary()
  def get_pretty_stats() do
    %{pending: pending, received: received, failed: failed} =
      PiMonitor.Storage.get_grouped(PiMonitor.Storage, 3600)

    "Pending: #{pending}, Received: #{received}, Failed: #{failed}, Failure rate: #{failed / max(received + failed, 1) * 100}%"
  end

  @spec print_pretty_stats :: :ok
  def print_pretty_stats() do
    IO.puts(get_pretty_stats())
  end

  @spec periodic_stats :: :timer.tref()
  def periodic_stats() do
    IO.puts("")
    print_pretty_stats()
    {:ok, tref} = :timer.apply_interval(5000, __MODULE__, :print_pretty_stats, [])
    tref
  end
end
