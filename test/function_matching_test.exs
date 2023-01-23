defmodule Jx.FunctionMatchTest do
  use ExUnit.Case

  require Jx
  import Jx

  describe "via: FunctionMatch" do
    test "{a, b} = jx.([1, 2])" do
      j {a, b} = jx.([1, 2])
      assert {a, b} === {1, 2}
      assert jx === Function.capture(List, :to_tuple, 1) # Avoids issue with inlining.
    end

    test "[1,3,9] = jx.(139)" do
      j [1,3,9] = jx.(139)
      assert jx === &Integer.digits/1
    end

    test "[a, b] = jx.(139, 12)" do
      j [a, b] = jx.(139, 12)
      assert {a, b} === {11, 7}
      assert jx === &Integer.digits/2
    end

    test "139 = jx.([5, 19], 24)" do
      j 139 = jx.([5, 19], 24)
      assert jx === &Integer.undigits/2
    end

    test "[[a,b], [1,b,a]] = [jx.(93), jx.(139)]" do
      j [[a,b], [1,b,a]] = [jx.(93), jx.(139)]
      assert jx === &Integer.digits/1
      assert {a, b} === {9, 3}
    end

    test "[[a,b], [a,b]] = [jx.(93), jx.(39)]" do
      assert_raise MatchError, fn ->
        j [[a,b], [a,b]] = [jx.(93), jx.(39)]
      end
    end
  end
end