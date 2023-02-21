defmodule Jx.FunctionMatching do
  @moduledoc false

  def j({:=, _, [pattern, list]} = expr) when is_list(pattern) and is_list(list) do
    if length(pattern) === length(list) do
      path = 
        [pattern, list]
        |> Enum.zip
        |> Enum.map(fn {a, b} -> 
          %Jx{expr: {:=, [], [a, b]}, index: nil} 
        end)
        |> List.update_at(0, &{%Jx{}, &1})
      next(%Jx{expr: expr, index: {path, []}})
    else
      %Jx{no_match: true}
    end
  end

  def j({:=, _, [{:{}, _, pattern}, {:{}, _, list}]}) when is_list(pattern) and is_list(list) do
    if length(pattern) === length(list) do
      j({:=, [], [pattern, list]})
    else
      %Jx{no_match: true}
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

  def j({:=, _, [lhs, {{:., _, [function]}, _, args}]}) do
    fun_info = function |> :erlang.fun_info |> Map.new
    case fun_info do
      %{type: :local} ->
        throw :unimplemented

      %{module: module, name: name} ->
        j({:=, [], [lhs, {{:., [], [{:__aliases__, [], [module]}, name]}, [], args}]})
    end
  end

  def j({:=, _, [lhs, {{:., _, [{:__aliases__, _, _} = aliases, function_name]}, _, args}]} = expr0) when is_atom(function_name) do
    expr = {:=, [], [lhs, {function_name, [], args}]}

    module = Macro.expand(aliases, __ENV__)
    catalog_module = Module.concat(Jx.Catalog, module)
    
    index = [{catalog_module, :j, [expr]}, {Jx.FunctionMatching, :elixir_j, [expr0]}]

    next(%Jx{expr: expr, index: index})
  end

  def j({:=, _, [lhs, {{:., _, [module, function_name]}, _, args}]}) when is_atom(module) and is_atom(function_name) do
    j({:=, [], [lhs, {{:., [], [{:__aliases__, [alias: false], module}, function_name]}, [], args}]})
  end

  def j({:=, _, [_, _]} = expr) do
    elixir_j(expr)
  end

  def elixir_j({:=, _, [_, _]} = expr) do
    # Evaluate using Elixir matching.
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
        %Jx{binding: Enum.into(binding, %{}), index: nil}
    end
  end
  
  def next(%Jx{expr: expr, index: index} = context) when is_list(index) do
    index
    |> Stream.unfold(fn
      ([]) -> nil

      ([{module, function_name, args} | rest]) ->

        case apply(module, function_name, args) do
          nil ->
            {nil, rest}

          %Jx{no_match: true} = j -> {j, []}

          %Jx{expr: expr, index: index, binding: binding} ->          
            case index do
              nil when expr === nil ->
                binding = Map.merge(context.binding, binding)

                index = [index | rest]
                {%Jx{binding: binding, index: index}, index}

              nil ->
                case expr |> Jx.apply_binding(context) |> j do
                  %Jx{no_match: true} ->
                    {nil, rest}

                  %Jx{binding: binding} = j ->
                    binding = Map.merge(context.binding, binding)

                    index = [j.index | rest]
                    {%Jx{binding: binding, index: index}, index}
                end

              list when is_list(list) ->
                {nil, index ++ rest}
            end
        end

      ([function | rest]) when is_function(function) ->
        {:=, _, [_, rhs]} = expr
        context = Jx.bind_function(rhs, function, %Jx{})
        new_expr = Jx.apply_binding(expr, context)
        match = j(new_expr)

        case match do
          %Jx{no_match: true} -> 
            {nil, rest}

          %Jx{binding: binding} ->
            binding = Map.merge(context.binding, binding)
            index = rest
            {%Jx{binding: binding, index: index}, index}
        end
    end)
    |> Stream.filter(fn %Jx{} -> true; _ -> false end)
    |> Enum.find_value(%Jx{no_match: true}, fn %Jx{} = j ->
      %Jx{j | expr: expr}
    end)
  end

  def next(%Jx{expr: expr0, index: {_, _} = index}) do
    index
    |> Stream.unfold(fn
      ({[], _}) -> nil

      ({[{%Jx{} = context, %Jx{expr: expr, index: index} = next} | _] = path, stack}) ->
        match = if index === nil do
          expr |> Jx.apply_binding(context) |> j
        else
          next(next)
        end

        case match do
          %Jx{no_match: true} ->
            if stack === [] do
              {nil, {[], []}}
            else
              path = List.update_at(path, 0, &elem(&1, 1))
              [next | stack] = stack
              {nil, {[next | path], stack}}
            end

          %Jx{binding: binding} = j ->
            binding = Map.merge(context.binding, binding)

            path = path |> tl |> List.update_at(0, &{%Jx{binding: binding}, &1})
            index = {path, [{context, %Jx{j | expr: expr}} | stack]}

            if path === [] do

              {%Jx{binding: binding, index: index}, index}
            else
              {nil, index}
            end
        end
    end)
    |> Stream.filter(fn %Jx{} -> true; _ -> false end)
    |> Enum.find_value(%Jx{no_match: true}, fn %Jx{} = j ->
      %Jx{j | expr: expr0}
    end)
  end
end