defmodule PiMonitorWeb.PingController do
  use PiMonitorWeb, :controller

  def index(conn, %{"last" => last, "stride" => stride}) do
    {stride_num, _} = Integer.parse(stride)
    pings = PiMonitor.Storage.get_as_json_medianized(min(10000, :erlang.binary_to_integer(last)) * stride_num, stride_num)
    render(conn, "index.json", pings: pings)
  end

  def index(conn, %{"timestamp" => timestamp}) do
    {ts, _} = Integer.parse(timestamp)
    pings = PiMonitor.Storage.get_by_timestamp(ts * 1000000, (ts + 86400000) * 1000000)
    render(conn, "index.json", pings: pings)
  end

end
