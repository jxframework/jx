defmodule Jx.Catalog.Helper do
  @moduledoc false

  def define_catalog_module(module, options \\ []) do
    only_keys = case options[:only] do
      nil ->
        module |> apply(:__info__, [:functions]) |> MapSet.new

      names when is_list(names) ->
        MapSet.new(names)
    end
    except = options |> Keyword.get(:except, []) |> MapSet.new
    included_keys = MapSet.difference(only_keys, except)

    extra_defs = Keyword.get(options, :defs, [])

    quote do
      defmodule unquote(Module.concat(Jx.Catalog, module)) do
        @moduledoc false

        unquote_splicing(extra_defs)

        def j({:&, _, [{:/, _, [{:j, _, _}, arity]}]} = a) do
          included_keys = unquote(Macro.escape(included_keys))

          index = Enum.flat_map(included_keys, fn
            {name, ^arity} -> [Function.capture(unquote(module), name, arity)]
            _ -> []
          end)

          %Jx{index: index}
        end

        def j(expr) do
          nil
        end
      end
    end
  end
end

defmodule Jx.Catalog do
  @moduledoc """
  This module tracks the modules and functions that are used as possible matches in function matching. 
  """
  alias __MODULE__
  alias Jx.Catalog.Helper

  module_info = [
    {
      Function, only: [identity: 1],
      defs: [
        quote do
          def j({:=, _, [pattern, {:identity, _, [arg1]}]}) do
            %Jx{expr: {:=, [], [pattern, arg1]}, index: nil}
          end
        end
      ]
    },
    {
      Integer, except: [to_char_list: 1, to_char_list: 2],
      defs: [
        quote do
          def j({:=, _, [pattern, {:pow, _, args}]}) do
            Catalog.Kernel.j({:=, [], [pattern, {:**, [], args}]})
          end
        end
      ]
    }, 
    { 
      List, 
      defs: [
        quote do
          def j({:=, _, [{:j, _, _}, {:duplicate, _, _}]}) do
            nil
          end

          def j({:=, _, [lhs, {:duplicate, _, [_, b]}]}) when is_list(lhs) and is_integer(b) do
            if length(lhs) !== b do
              %Jx{no_match: true}
            else
              nil
            end
          end

          def j({:=, _, [lhs, {:duplicate, _, [_, _]}]}) do
            %Jx{no_match: true}
          end
        end
      ]
    },
    Tuple, Bitwise, 
    {
      Enum, except: [chunk: 2, partition: 2, uniq: 2, shuffe: 1, random: 1],
      defs: [
        quote do
          def j({:=, _, [_, {:group_by, _, [_enumerable, key_fun]}]}) when not is_function(key_fun) do
            %Jx{no_match: true}
          end

          def j({:=, _, [_, {:into, _, [_, [_ | _]]}]}) do
            %Jx{no_match: true}
          end
        end
      ] 
    },
    { 
      Keyword, except: [size: 1, map: 2]
    }, 
    {
      String, except: [
        to_atom: 1, rstrip: 1, valid_character?: 1, strip: 1, lstrip: 1, next_grapheme_size: 1, to_char_list: 1, ljust: 2, rjust: 2, strip: 2, lstrip: 2, rstrip: 2
      ]
    },
    {
      Kernel, only: [
        **: 2, ++: 2, --: 2, get_in: 2, max: 2, min: 2, put_elem: 3,
        *: 2, +: 1, +: 2, -: 1, -: 2, /: 2, !=: 2, !==: 2, <: 2, <=: 2, ==: 2, ===: 2, >: 2, >=: 2,
        abs: 1, binary_part: 3, bit_size: 1, byte_size: 1, ceil: 1, div: 2, elem: 2, floor: 1, hd: 1, 
        is_atom: 1, is_binary: 1, is_bitstring: 1, is_boolean: 1, is_float: 1, is_function: 1, is_function: 2, is_integer: 1, is_list: 1, is_map: 1,
        is_map_key: 2, is_number: 1, is_pid: 1, is_port: 1, is_reference: 1, is_tuple: 1, 
        length: 1, map_size: 1, not: 1, rem: 2, round: 1, tl: 1, trunc: 1, tuple_size: 1
      ],
      defs: [
        quote do
          def j({:=, _, [x, {:+, _, [a, {:j, _, _} = j]}]}) do
            %Jx{expr: {:=, [], [x - a, j]}, index: nil}
          end

          def j({:=, _, [x, {:+, _, [{:j, _, _} = j, a]}]}) do
            %Jx{expr: {:=, [], [x - a, j]}, index: nil}
          end

          def j({:=, _, [x, {:*, _, [0, {:j, _, _} = j]}]}) when is_integer(x) and x !== 0 do
            %Jx{no_match: true} 
          end

          def j({:=, _, [x, {:*, _, [{:j, _, _} = j, 0]}]}) when is_integer(x) and x !== 0 do
            %Jx{no_match: true} 
          end

          def j({:=, _, [x, {:*, _, [a, {:j, _, _} = j]}]}) when is_integer(x) and is_integer(a) and a !== 0 do
            %Jx{expr: {:=, [], [div(x, a), j]}, index: nil} 
          end

          def j({:=, _, [x, {:*, _, [{:j, _, _} = j, a]}]}) when is_integer(x) and is_integer(a) and a !== 0 do
            %Jx{expr: {:=, [], [div(x, a), j]}, index: nil} 
          end

          def j({:=, _, [x, {:**, _, [1, _]}]}) when is_integer(x) and x > 1 do
            %Jx{no_match: true}
          end

          def j({:=, _, [x, {:**, _, [a, term]}]} = expr) when is_integer(x) and x > 0 and is_integer(a) and a > 1 do
            case :math.log2(x) / :math.log2(a) do
              result when result - trunc(result) < 0.00001 ->
                %Jx{expr: {:=, [], [trunc(result), term]}, index: nil}
              _ ->
                %Jx{no_match: true}
            end
          end

          def j({:=, _, [x, {:**, _, [x, b]}]}) when is_integer(x) and x > 0 and is_integer(b) do
            case {x, b} do
              {0, 0} -> %Jx{no_match: true}
              {1, 0} -> %Jx{expr: {:=, [], [x, x]}, index: nil}
              {_, 1} -> %Jx{expr: {:=, [], [x, x]}, index: nil}
              {_, _} -> %Jx{no_match: true}
            end
          end

          def j({:=, _, [_, {:**, _, _}]}) do
            %Jx{no_match: true}
          end
        end
      ]
    }
  ]

  module_info
  |> Stream.map(fn
    (module) when is_atom(module) -> {module, []}
    info -> info
  end)
  |> Enum.each(fn {module, options} ->
      quoted_code = Helper.define_catalog_module(module, options)
      Module.eval_quoted(__MODULE__, quoted_code)
  end)

  @_modules Enum.map(module_info, fn {name, _} -> name; name -> name end)

  @doc """
  Returns a `%Jx{}` context that searches the modules of the catalog for a match.
  
  ## Examples
  ```elixir 
  iex> Jx.Catalog.j(quote(do: &j/1))
  #Jx<>
  ```
  """
  def j({:&, _, [{:/, _, [{:j, _, atom}, _arity]}]} = expr) when is_atom(atom) do
    modules = @_modules
    index = for m <- modules, do: {Module.concat(__MODULE__, m), :j, [expr]}
    %Jx{index: index}
  end
end