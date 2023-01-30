defmodule Jx.FunctionMatching do
  @moduledoc false

  require Logger

  def j({:=, _, [lhs, rhs]} = expr) when is_list(lhs) and is_list(rhs) do
    if length(lhs) !== length(rhs) do
      raise MatchError

    else
      index = {
        [lhs, rhs] |> Enum.zip |> Enum.map(fn {a, b} -> {:=, [], [a, b]} end),
        %Jx{},
        []
      }
      next(%Jx{expr: expr, index: index})
    end
  end

  def j({:=, _, [{:{}, _, lhs}, {:{}, _, rhs}]}) do
    if length(lhs) !== length(rhs) do
      raise MatchError

    else
      j({:=, [], [lhs, rhs]})
    end
  end

  def j({:=, _, [{a, b}, {c, d}]}) do
    j({:=, [], [{:{}, [], [a, b]}, {:{}, [], [c, d]}]})
  end

  def j({:=, _, [_, {:j, _, args}]} = expr) when is_list(args) do
    query = quote do
      &unquote({:j, [], nil})/unquote(length(args))
    end
    index = [{Jx.Catalog, :j, [query]}]

    next(%Jx{expr: expr, index: index})
  end

  def j({:=, _, [_, _]} = expr) do
    try do
      Code.eval_quoted(expr)
    rescue
      _ ->
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
  
  defp next(%Jx{expr: {:=, _, [a,b]}, index: index}) when is_list(index) do
    Stream.unfold(index, fn
      ([]) -> nil

      ([function | rest]) when is_function(function) ->
        context = Jx.bind_function(b, function, %Jx{})
        b = Jx.apply_binding(b, context)
        
        case j({:=, [], [a,b]}) do
          %Jx{no_match: true} = j -> 
            {j, rest}

          j ->
            binding = Map.merge(j.binding, context.binding, fn
              (_, v, v) -> v
              (_, _, _) -> raise MatchError
            end)

            {%Jx{binding: binding, index: rest}, rest}
        end

      ([{module, function_name, args} | rest]) ->
        %Jx{index: index} = apply(module, function_name, args)
        {%Jx{no_match: true}, index ++ rest}

    end)
    |> Enum.find_value(%Jx{no_match: true}, fn
      (%Jx{no_match: true}) -> nil

      (result) -> result
    end)
  end

  defp next(%Jx{index: {_, _, _} = index}) do
    index
    |> Stream.unfold(fn
      ({[], _ctx, []}) -> nil

      ({[], _ctx, [{expr, ctx} | rest]}) ->
        {%Jx{no_match: true}, {[expr], ctx, rest}}

      ({[%Jx{expr: expr} = match | rest], ctx, stack}) ->

        case next(match) do
          %Jx{no_match: true} when stack === [] -> nil

          %Jx{no_match: true} = j ->
            [{prev_match, prev_context} | stack] = stack
            {j, {[prev_match, match | rest], prev_context, stack}}

          j when rest === [] ->
            binding = Map.merge(j.binding, ctx.binding, fn
              (_, v, v) -> v
              (_, _, _) -> raise MatchError
            end)

            index = {rest, %Jx{binding: binding}, [{%Jx{j | expr: expr}, ctx} | stack]}
            {%Jx{binding: binding, index: index}, index}

          j ->
            binding = Map.merge(j.binding, ctx.binding, fn
              (_, v, v) -> v
              (_, _, _) -> raise MatchError
            end)

            {%Jx{no_match: true}, {rest, %Jx{binding: binding}, [{%Jx{j | expr: expr}, ctx} | stack]} }
        end

      ({[{:=, _, [_, _]} = expr | rest], ctx, stack}) ->
        match =
          expr
          |> Jx.apply_binding(ctx)
          |> j

        case match do
          %Jx{no_match: true} when stack === [] -> nil

          %Jx{no_match: true} = j ->
            [{prev_match, prev_context} | stack] = stack
            {j, {[prev_match, expr | rest], prev_context, stack}}

          j when rest === [] ->
            binding = Map.merge(j.binding, ctx.binding, fn
              (_, v, v) -> v
              (_, _, _) -> raise MatchError
            end)

            index = {rest, %Jx{binding: binding}, [{%Jx{j | expr: expr}, ctx} | stack]}
            {%Jx{binding: binding, index: index}, index}

          j ->
            binding = Map.merge(j.binding, ctx.binding, fn
              (_, v, v) -> v
              (_, _, _) -> raise MatchError
            end)

            {%Jx{no_match: true}, {rest, %Jx{binding: binding}, [{%Jx{j | expr: expr}, ctx} | stack]} }
        end
    end)
    |> Enum.find_value(%Jx{no_match: true}, fn
      (%Jx{no_match: true}) -> nil
      (result) -> result
    end)
  end
end