defmodule GlobalPulseTest do
  use ExUnit.Case
  doctest GlobalPulse

  test "greets the world" do
    assert GlobalPulse.hello() == :world
  end
end
