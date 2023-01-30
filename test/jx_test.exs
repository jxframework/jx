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

  describe "apply_binding/2" do
    test "j(a)" do
      result = apply_binding({:j, [jx_name: :jx, line: 9], [[1, 2]]}, %Jx{binding: %{jx: &Function.identity/1}})
      assert {{:., [], [&Function.identity/1]}, [], [[1, 2]]} === result 
    end

    test "a = j(b)" do
      term = {:=, [], [{:a, [line: 50], nil}, {:j, [jx_name: :jx, line: 50], [23, 1]}]}
      context = %Jx{binding: %{a: 0, jx: &Integer.floor_div/2}}
      result = apply_binding(term, context)
      assert {:=, [], [0, {{:., [], [&Integer.floor_div/2]}, [], [23, 1]}]} === result
    end
  end

  describe "bind_function/3" do
    test "jx => &Integer.digits/1, empty context" do
      term = {:j, [jx_name: :jx, line: 88], [2023]}
      value = &Integer.digits/1

      result = bind_function(term, value, %Jx{})
      assert %Jx{binding: binding} = result
      assert %{jx: &Integer.digits/1} === binding
    end    
  end
end