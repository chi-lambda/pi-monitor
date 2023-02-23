defmodule PiMonitorWeb.PingController do
  use PiMonitorWeb, :controller

  def index(conn, %{"last" => last}) do
    pings = PiMonitor.Storage.get_as_json(PiMonitor.Storage, min(10000, :erlang.binary_to_integer(last)))
    render(conn, "index.json", pings: pings)
  end

end
