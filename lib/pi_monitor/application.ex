defmodule PiMonitor.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: PiMonitor.Task.Supervisor},
      {PiMonitor.Storage, name: PiMonitor.Storage},
      {PiMonitor.Pinger, name: PiMonitor.Pinger},
      {PiMonitor.Telegram.Notifier, name: PiMonitor.Telegram.Notifier},
      {PiMonitor.Telegram.Updater, name: PiMonitor.Telegram.Updater}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PiMonitor.Supervisor, max_restarts: 100]
    Supervisor.start_link(children, opts)
  end
end
