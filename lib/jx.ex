defmodule Jx do
  @moduledoc """
  This is the documentation for the Jx framework project.
  """

  defstruct [binding: %{}, no_match: false, index: [], expr: nil]

  @doc false
  def apply_binding(term, %Jx{binding: binding}) do
    Macro.prewalk(term, fn 
      ({:j, meta, args} = t) ->
        name = meta[:jx_name]
        case binding[name] do
          nil -> t
          val -> quote do
            unquote(val).(unquote_splicing(args))
          end
        end

      ({var_name, _meta, context} = t) when is_atom(context) ->
        case binding[var_name] do
          nil -> t
          val -> Macro.escape(val)
        end

      (t) -> t
    end)
  end

  @doc false
  def bind_function({:j, meta, _}, value, %Jx{} = context) do
    case Keyword.get(meta, :jx_name) do
      nil ->
        raise ArgumentError
      name ->
        put_in(context.binding[name], value)
    end
  end

  defimpl Inspect do
    def inspect(%Jx{no_match: true}, _opts) do
      "#Jx<no match>"
    end

    def inspect(%Jx{binding: %{} = binding}, _opts) do
      binding 
      |> Enum.sort 
      |> Enum.map(fn {k, v} -> "#{k}=#{inspect(v)}" end) 
      |> Enum.join(", ")
      |> (&"#Jx<#{&1}>").()
    end

    def inspect(%Jx{binding: binding}, _opts) do
      binding 
      |> Enum.sort 
      |> Enum.map(fn {k, v} -> "#{k}=#{inspect(v)}" end) 
      |> Enum.join(", ")
      |> (&"#Jx<#{&1}>").()
    end
  end

  defmodule J do
    @moduledoc false

    def j(expr) do
      Jx.FunctionMatching.j(expr)
    end
  end

  @doc """
  Makes the match expression following it "jacked" allowing 'j' prefixed variables to be bound to functions.

  Under the hood a call is introduced to a function that implements the specific logic to handle the expresssion.
  The expression is passed to the implementing function in quoted form but with with any 'j' prefixed variables
  being called as functions such as `jx.(...)` replaced with `j(...)` function calls.

  ## Examples
  ```elixir 
  iex> require Jx; import Jx
  iex> j a = 1
  #Jx<a=1>
  ```

  ```elixir
  iex> require Jx; import Jx
  iex> j [[2, 0, a, b], [1, a, b]] = [jx.(2023), jx.(123)]
  #Jx<a=2, b=3, jx=&Integer.digits/1>
  iex> jx.(a * 10 + b)
  [2, 3]
  ```
  """
  defmacro j(expr) do
    macro_j(expr)
  end

  defp macro_j({:=, meta, [left, right]}) do
    {left, vars_left} = parse_left(left, MapSet.new)
    {has_j, right, vars_right} = parse_right(right) # XXX: handling has_j=false
    vars = MapSet.union(vars_left, vars_right)

    right = if has_j do
      right
    else
      quote do
        Macro.escape(unquote(right))
      end
    end

    term = {:{}, [], [:=, meta, [Macro.escape(left), right]]}
    match_rhs = quote do
      Jx.J.j(unquote(term))
    end

    variable_matchers =
      vars
      |> Enum.filter(fn :j -> false; _ -> true end)
      |> Enum.flat_map(fn
        (:j) -> []
        (name) ->
          [{name, Macro.var(name, nil)}]
      end)
      |> Enum.sort
    match_lhs = quote do
      %Jx{binding: %{unquote_splicing(variable_matchers)}, no_match: false}
    end

    quote do
      unquote(match_lhs) = unquote(match_rhs)
    end
  end

  defp macro_j(_) do
    raise ArgumentError
  end

  defp parse_left(term, acc) do
    case term do
      {name, _meta, context} when is_atom(name) and is_atom(context) ->
        if name |> Atom.to_string |> String.starts_with?("j") do
          raise ArgumentError
        end

        {term, MapSet.put(acc, name)}

      {:^, _, _} -> # Pin operator not supported yet.
        raise ArgumentError

      {:{}, meta, args} when is_list(args) ->
        {args, acc} = parse_left(args, acc)
        {{:{}, meta, args}, acc}

      {_, _, _} ->
        raise ArgumentError

      {a, b} ->
        {[a, b], acc} = Enum.map_reduce([a, b], acc, &parse_left/2)
        {{a, b}, acc}

      list when is_list(list) ->
        Enum.map_reduce(list, acc, &parse_left/2)

      t when is_number(t) or is_atom(t) or is_binary(t) ->
        {t, acc}
    end
  end

  # Tuple literal
  defp parse_right({a, b}) do
    {has_j_a, a, vars_a} = parse_right(a)
    {has_j_b, b, vars_b} = parse_right(b)
    vars = MapSet.union(vars_a, vars_b)

    case {has_j_a, has_j_b} do
      {true, true} -> {true, {a, b}, vars}
      {false, false} -> {false, {a, b}, vars}
      {true, false} ->
        b = quote do
          Macro.escape(unquote(b))
        end
        {true, {a, b}, vars}
      {false, true} ->
        a = quote do
          Macro.escape(unquote(a))
        end
        {true, {a, b}, vars}
    end
  end

  # List term
  defp parse_right(list) when is_list(list) do
    {terms, {any_has_j, vars}} = Enum.map_reduce(list, {false, MapSet.new()}, fn term, {has_j0, vars0} ->
      {has_j, term, vars} = parse_right(term)
      {{has_j, term}, {has_j0 or has_j, MapSet.union(vars0, vars)}}
    end)

    terms = if any_has_j do
      Enum.map(terms, fn 
        ({true, term}) -> term
        ({false, term}) ->
          quote do
            Macro.escape(unquote(term))
          end
      end)
    else
      Enum.map(terms, &elem(&1, 1))
    end

    {any_has_j, terms, vars}
  end

  # Function calls
  defp parse_right({{:., dot_meta, dot_args}, meta, args}) when is_list(args) do
    fn_variable_name = case dot_args do
      [{name, _, _}] when is_atom(name) -> name
      _ -> nil
    end

    is_j_variable = fn_variable_name |> Atom.to_string |> String.starts_with?("j")
    if is_j_variable do
      meta = Keyword.put(meta, :jx_name, fn_variable_name)
      
      {has_j, args, vars} = parse_right(args)
      args = if has_j do
        args
      else
        quote do
          Macro.escape(unquote(args))
        end
      end
      vars = [fn_variable_name] |> MapSet.new |> MapSet.union(vars)
      
      {true, {:{}, [], [:j, meta, args]}, vars}
    
    else
      {has_j, dot_args, _} = parse_right(dot_args) # XXX: generalize to true and handling vars
      if has_j, do: throw :unimplemented

      {has_j, args, vars} = parse_right(args)

      expr = if has_j do
        {:{}, [], [{:{}, [], [:., dot_meta, dot_args]}, meta, args]}
      else
        {{:., dot_meta, dot_args}, meta, args}
      end 

      {has_j, expr, vars}
    end
  end

  # Function terms
  defp parse_right({name, meta, args}) when is_atom(name) and is_list(args) do
    case parse_right(args) do
      {false, args, vars} -> {false, {name, meta, args}, vars}
      
      {true, args, vars} ->
        {true, {:{}, [], [name, meta, args]}, vars}
    end
  end

  # Variable terms
  defp parse_right({name, meta, context} = term) when is_atom(name) and is_atom(context) do
    is_j_variable = name |> Atom.to_string |> String.starts_with?("j")
    if is_j_variable do
      meta = put_in(meta[:jx_is_term], true)
      parse_right({{:., [], [term]}, meta, []})
    else
      {false, term, MapSet.new()}
    end
  end

  # Literal
  defp parse_right(term) do
    {false, term, MapSet.new()}
  end
end