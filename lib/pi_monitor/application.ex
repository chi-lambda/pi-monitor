defmodule PiMonitor.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: PiMonitor.Task.Supervisor},
      {PiMonitor.Storage, name: PiMonitor.Storage, timeout: :infinity},
      {PiMonitor.Pinger, name: PiMonitor.Pinger},
      # {PiMonitor.Telegram.Notifier, name: PiMonitor.Telegram.Notifier},
      # {PiMonitor.Telegram.Updater, name: PiMonitor.Telegram.Updater},
      # Start the PubSub system
      {Phoenix.PubSub, name: PiMonitor.PubSub},
      # Start the Endpoint (http/https)
      PiMonitorWeb.Endpoint
      # Start a worker by calling: PiMonitor.Worker.start_link(arg)
      # {PiMonitor.Worker, arg}
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PiMonitor.Supervisor, max_restarts: 100]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PiMonitorWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
