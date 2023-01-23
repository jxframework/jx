defmodule Jx.FunctionMatching do
  @moduledoc false

  def j({:=, _, [lhs, rhs]}) when is_list(lhs) and is_list(rhs) do
    if length(lhs) !== length(rhs) do
      raise MatchError

    else
      pairs = Enum.zip(lhs, rhs)
      matches = Enum.map(pairs, fn {a, b} ->
        j({:=, [], [a, b]})
      end)

      binding = Enum.reduce(matches, %{}, fn %Jx{} = context, acc ->
        Map.merge(acc, context.binding, fn
          (_, v, v) -> v
          (_, _, _) -> raise MatchError
        end)
      end)

      %Jx{binding: binding}
    end
  end

  def j({:=, _, [a, {:j, meta, args}]}) do
    args = Enum.map(args, fn
      {:{}, _, _} = arg -> arg |> Code.eval_quoted |> elem(0)
      {:j, _, _} = arg -> arg
      {_, _, _} -> raise ArgumentError
      arg -> arg 
    end)

    arity = length(args)

    fns = Stream.flat_map(Jx.Catalog.modules, &apply(Module.concat(Jx.Catalog, &1), :fetch, [[arity: arity]]))

    create_expression = fn x ->
      quote do
        unquote(a) = unquote(Macro.escape(x))
      end
    end

    case search_for_match(fns, args, create_expression) do
      nil ->
        %Jx{no_match: true}
        
      {match, j = %Jx{}} ->
        case Keyword.get(meta, :jx_name) do
          nil ->
            j
          name ->
            put_in j.binding[name], match
        end
    end
  end

  def j({:=, _, [_, _]} = expr) do
    elixir_match(expr)
  end
    
  defp search_for_match(fns, args, create_expression) do
    Enum.find_value(fns, fn func ->
      try do
        expr = func |> apply(args) |> create_expression.()
        case elixir_match(expr) do
          %Jx{no_match: false} = j -> {func, j}
          _ -> nil
        end
      rescue
        _ -> nil
      end
    end)
  end

  defp elixir_match(expr) do
    try do
      Code.eval_quoted(expr)
    rescue
      _e in [MatchError] ->
        %Jx{no_match: true}
    else
      {_result, binding} ->
        binding = Enum.map(binding, fn
          {{var, _}, val} -> {var, val}
          {var, val} when is_atom(var) -> {var, val}
        end)
        %Jx{binding: Enum.into(binding, %{})}
    end
  end
end