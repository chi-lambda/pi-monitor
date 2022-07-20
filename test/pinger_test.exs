defmodule PingerTest do
  use ExUnit.Case
  doctest PiMonitor

  test "greets the world" do
    assert PiMonitor.hello() == :world
  end
end
