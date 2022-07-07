defmodule ExpelTest do
  use ExUnit.Case
  doctest Expel

  test "greets the world" do
    assert Expel.hello() == :world
  end
end
