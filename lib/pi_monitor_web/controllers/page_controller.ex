defmodule PiMonitorWeb.PageController do
  use PiMonitorWeb, :controller

  def index(conn, _params) do
    render(conn, "index.html")
  end
end
