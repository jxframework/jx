defmodule Jx.FunctionMatchingTest do
  use ExUnit.Case

  require Jx
  import Jx

  describe "single function variable" do
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
  end

  describe "list of function variables" do
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

    test "[[1,2], [[1], [2]]] = [jx.([1], [2]), jx.([[1]], [[2]])]" do
      j [[1,2], [[1], [2]]] = [jx.([1], [2]), jx.([[1]], [[2]])]
      assert [[1,2], [[1], [2]]] = [jx.([1], [2]), jx.([[1]], [[2]])]
    end

    test "[a, a] = [jx.(1, 23), jx.(23, 1)]" do
      j [a, a] = [jx.(1, 23), jx.(23, 1)]
      assert [a, a] === [jx.(1, 23), jx.(23, 1)]
    end
  end
 
  describe "tuple of function variables" do
    test "{1} = {jx.(1)}" do
      j {1} = {jx.(1)}
      assert jx === &Function.identity/1
    end

    test "{[a,b], [1,b,a]} = {jx.(93), jx.(139)}" do
      j [[a,b], [1,b,a]] = [jx.(93), jx.(139)]
      assert jx === &Integer.digits/1
      assert {a, b} === {9, 3}
    end

    test "{\"[\", \"j\", \"]\"} = {jx.(91), jx.(106), jx.(93)}" do
      j {"[", "j", "]"} = {jx.([91]), jx.([106]), jx.([93])}
      assert jx === &List.to_string/1
    end

    test "{\"[\", a, \"]\"} = {jx.(91), jx.(106), jx.(93)}" do
      j {"[", a, "]"} = {jx.([91]), jx.([106]), jx.([93])}
      assert a === "j"
      assert jx === &List.to_string/1
    end
  end

  describe "no match" do
    test "[1, 99] = [jx.(1), jy.(2)]" do
      assert_raise MatchError, fn ->
        j [1, 99] = [jx.(1), jy.(2)]
      end
    end
  end

  describe "nested function variables" do
    test "8 = jx.(2, jy.(2,3))" do
      j 8 = jx.(2, jy.(2, 3))

      assert 8 === jx.(2, jy.(2, 3))

      # Multiple options possible:
      # jx=&Kernel.+/2, jy=&Kernel.*/2
      # jx=&Integer.pow/2, jy=&Bitwise.bor/2
    end
    
    test "10 = jx.(2, jy.(2,3))" do
      j 10 = jx.(2, jy.(2, 3))

      assert jx === Function.capture(Kernel, :+, 2)
      assert jy === &Integer.pow/2
    end

    test "{10, 32} = {jx.(2, jy.(2,3)), jy.(2, jx.(2,3))}" do
      j {10, 32} = {jx.(2, jy.(2,3)), jy.(2, jx.(2,3))}

      assert jx === Function.capture(Kernel, :+, 2)
      assert jy === &Integer.pow/2
    end

    test "{32, 10} = {jx.(2, jy.(2,3)), jy.(2, jx.(2,3))}" do
      j {32, 10} = {jx.(2, jy.(2,3)), jy.(2, jx.(2,3))}

      assert jx === &Integer.pow/2
      assert jy === Function.capture(Kernel, :+, 2)
    end

    test "{10, 8} = {jx.(2, jy.(2,3)), jy.(2, jx.(2,3))}" do
      j {10, 8} = {jx.(2, jy.(2,3)), jy.(2, jx.(2,3))}

      assert jx === Function.capture(Kernel, :*, 2)
      assert jy === Function.capture(Kernel, :+, 2)
    end

    test "93 = jx.(1, jy.(23,4))" do
      j 93 = jx.(1, jy.(23,4))

      assert jx === Function.capture(Kernel, :+, 2)
      assert jy === Function.capture(Kernel, :*, 2)
    end

    test "93 = jx.(jy.(23,4), 1)" do
      j 93 = jx.(jy.(23,4), 1)

      assert jx === Function.capture(Kernel, :+, 2)
      assert jy === Function.capture(Kernel, :*, 2)
    end

    test "12 = jx.(2, jy.(2,3))" do
      j 12 = jx.(2, jy.(2, 3))

      assert jx === Function.capture(Kernel, :*, 2)
      assert jy === Function.capture(Kernel, :*, 2)
    end
 
    test "16 = jx.(2, jy.(2,3))" do
      j 16 = jx.(2, jy.(2, 3))

      assert jx === Function.capture(Kernel, :*, 2)
      assert jy === &Integer.pow/2
    end
  end

  describe "regular variables in expression of match operator" do
    test "a = 1; j 1 = a" do
      a = 1
      j 1 = a
    end

    test "a = 1; j 1 = jx.(a)" do
      a = 1
      j 1 = jx.(a)
      assert jx === &Function.identity/1
    end

    test "f = &Function.identity/1; j 1 = f.(1)" do
      f = &Function.identity/1
      j 1 = f.(1)
    end

    test "f = fn x -> x end; j 1 = f.(1)" do
      f = fn x -> x end
      j 1 = f.(1)
    end

    test "f = &(&1); j 1 = f.(1)" do
      f = &(&1)
      j 1 = f.(1)
    end
  end

  describe "regular variables in expression of match operator mixed with j variables" do
    test "f = &Function.identity/1; j 1 = f.(jx.(1))" do
      f = &Function.identity/1
      j 1 = f.(jx.(1))
      assert jx === &Function.identity/1
    end

    test "f = fn x -> x end; j 1 = f.(jx.(1))" do
      f = fn x -> x end
      assert catch_throw(j 1 = f.(jx.(1))) === :unimplemented
    end

    test "f = &(&1); j 1 = f.(jx.(1))" do
      f = &(&1)
      assert catch_throw(j 1 = f.(jx.(1))) === :unimplemented
    end

    test "f = &Function.identity/1; j 1 = (f.(jx)).(1)" do
      # f = &Function.identity/1
      # j 1 = (f.(jx)).(1))

      assert catch_throw(Macro.expand(quote do
        j 1 = (f.(jx)).(1)
      end, __ENV__)) === :unimplemented
    end

    test "a = 2; j 10 = jx.(a, jy.(a,3))" do
      a = 2
      j 10 = jx.(a, jy.(a,3))

      assert jx === Function.capture(Kernel, :+, 2)
      assert jy === &Integer.pow/2
    end

    test "a = 2; b = 3; j {10, 8} = {jx.(2, jy.(a,b)), jy.(a, jx.(2,3))}" do
      a = 2
      b = 3
      j {10, 8} = {jx.(2, jy.(a,b)), jy.(a, jx.(2,3))}

      assert jx === Function.capture(Kernel, :*, 2)
      assert jy === Function.capture(Kernel, :+, 2)
    end

    test "list = [5, 19]; j 139 = jx.(list, 24)" do
      list = [5, 19]
      j 139 = jx.(list, 24)
      assert jx === &Integer.undigits/2
    end
  end

  describe "Function module" do
    test "j 1 = Function.identity(jx.(1))" do
      j 1 = Function.identity(jx.(1))
      assert jx === &Function.identity/1
    end
  end
end