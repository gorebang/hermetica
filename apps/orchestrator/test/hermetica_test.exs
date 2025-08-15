defmodule HermeticaTest do
  use ExUnit.Case
  doctest Hermetica

  test "greets the world" do
    assert Hermetica.hello() == :world
  end
end
