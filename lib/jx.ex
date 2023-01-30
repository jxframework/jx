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
        put_in context.binding[name], value
    end
  end

  defimpl Inspect do
    def inspect(%Jx{no_match: true}, _opts) do
      "#Jx<no match>"
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
    {left, acc} = parse_left(left, MapSet.new)
    {right, acc} = parse_right(right, acc)

    term = Macro.escape({:=, meta, [left, right]})
    match_rhs = quote do
      Jx.J.j(unquote(term))
    end

    variable_matchers =
      acc
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

      {name, meta, args} when is_atom(name) and is_list(args) ->
        {args, acc} = parse_left(args, acc)
        {{name, meta, args}, acc}

      {a, b} ->
        {[a, b], acc} = Enum.map_reduce([a, b], acc, &parse_left/2)
        {{a, b}, acc}

      list when is_list(list) ->
        Enum.map_reduce(list, acc, &parse_left/2)

      t when is_number(t) or is_atom(t) or is_binary(t) ->
        {t, acc}
    end
  end

  defp parse_right({a, b}, acc) do
    {a, acc} = parse_right(a, acc)
    {b, acc} = parse_right(b, acc)
    {{a, b}, acc}
  end

  defp parse_right(args, acc) when is_list(args) do
    Enum.map_reduce(args, acc, &parse_right/2)
  end

  defp parse_right({{:., dot_meta, dot_args}, meta, args}, acc) when is_list(args) do
    function_variable_name = case dot_args do
      [{name, _, _}] when is_atom(name) -> name
      _ -> nil
    end

    is_j_variable = function_variable_name |> Atom.to_string |> String.starts_with?("j")

    if is_j_variable do
      meta = Keyword.put(meta, :jx_name, function_variable_name)
      acc = MapSet.put(acc, function_variable_name)
      {args, acc} = parse_right(args, acc)
      {{:j, meta, args}, acc}
    else
      {dot_args, acc} = parse_right(dot_args, acc)
      {args, acc} = parse_right(args, acc)

      {{{:., dot_meta, dot_args}, meta, args}, acc}
    end
  end

  defp parse_right({name, meta, args}, acc) when is_atom(name) and is_list(args) do
    {args, acc} = parse_right(args, acc)
    {{name, meta, args}, acc}
  end

  defp parse_right(term, acc) do
    {term, acc}
  end
end