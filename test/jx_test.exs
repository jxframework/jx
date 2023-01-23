defmodule JxTest do
  use ExUnit.Case
  doctest Jx

  require Jx
  import Jx

  describe "Elixir matching" do
    test "1 = 1" do
      j 1 = 1
    end

    test "1 = 2" do
      assert_raise MatchError, fn ->
        j 1 = 2
      end
    end
  end
end
