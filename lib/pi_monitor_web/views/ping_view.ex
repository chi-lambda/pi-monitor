defmodule PiMonitorWeb.PingView do
  use PiMonitorWeb, :view
  alias PiMonitorWeb.PingView

  def render("index.json", %{pings: pings}) do
    pings
  end

  def render("show.json", %{ping: ping}) do
    %{data: render_one(ping, PingView, "ping.json")}
  end

  def render("ping.json", %{ping: ping}) do
    %{
      id: ping.id
    }
  end
end
