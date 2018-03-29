defmodule PhoenixApiVersionsTest do
  use ExUnit.Case
  doctest PhoenixApiVersions

  test "greets the world" do
    assert PhoenixApiVersions.hello() == :world
  end
end
