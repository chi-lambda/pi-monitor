defmodule PiMonitorWeb.PingController do
  use PiMonitorWeb, :controller

  def index(conn, %{"last" => last, "stride" => stride}) do
    stride_num = :erlang.binary_to_integer(stride)
    pings = PiMonitor.Storage.get_as_json(min(10000, :erlang.binary_to_integer(last)) * stride_num, stride_num)
    render(conn, "index.json", pings: pings)
  end

end
