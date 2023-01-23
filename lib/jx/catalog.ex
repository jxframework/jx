defmodule Jx.Catalog.Helper do
  @moduledoc false

  def define_catalog_module(module, opts \\ []) do
    only_keys = case opts[:only] do
      nil ->
        module |> apply(:__info__, [:functions]) |> MapSet.new

      names when is_list(names) ->
        MapSet.new(names)
    end
    except = opts |> Keyword.get(:except, []) |> MapSet.new
    included_keys = MapSet.difference(only_keys, except)

    quote do
      defmodule unquote(Module.concat(Jx.Catalog, module)) do
        @moduledoc false

        def fetch([arity: arity]) do
          included_keys = unquote(Macro.escape(included_keys))

          Enum.flat_map(included_keys, fn
            {name, ^arity} -> [Function.capture(unquote(module), name, arity)]
            _ -> []
          end)
        end
      end
    end
  end
end

defmodule Jx.Catalog do
  @moduledoc """
  This module contains the modules and functions that are searched through for function matching. 
  """

  alias Jx.Catalog.Helper

  modules = [
    {
      Function, only: [identity: 1]
    },
    Integer, List, Tuple, Enum, Keyword, Bitwise,
    {
      String, except: [to_atom: 1]
    },
    {
      Kernel, only: [
        **: 2, ++: 2, --: 2, get_in: 2, max: 2, min: 2, put_elem: 3,
        *: 2, +: 1, +: 2, -: 1, -: 2, /: 2, !=: 2, !==: 2, <: 2, <=: 2, ==: 2, ===: 2, >: 2, >=: 2,
        abs: 1, binary_part: 3, bit_size: 1, byte_size: 1, ceil: 1, div: 2, elem: 2, floor: 1, hd: 1, 
        is_atom: 1, is_binary: 1, is_bitstring: 1, is_boolean: 1, is_float: 1, is_function: 1, is_function: 2, is_integer: 1, is_list: 1, is_map: 1,
        is_map_key: 2, is_number: 1, is_pid: 1, is_port: 1, is_reference: 1, is_tuple: 1, 
        length: 1, map_size: 1, not: 1, rem: 2, round: 1, tl: 1, trunc: 1, tuple_size: 1
      ]
    }
  ]

  @_modules Enum.map(modules, fn {name, _} -> name; name -> name end)

  @doc """
  Returns the list of modules available in the catalog.
  """
  def modules do
    @_modules
  end

  Enum.each(modules, fn 
    ({module, args}) ->
      quoted_code = Helper.define_catalog_module(module, args)
      Module.eval_quoted(__MODULE__, quoted_code)

    (module) ->
      quoted_code = Helper.define_catalog_module(module)
      Module.eval_quoted(__MODULE__, quoted_code)
  end)
end