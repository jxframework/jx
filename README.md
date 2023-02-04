# Jx

[![Package](https://img.shields.io/badge/-Package-important)](https://hex.pm/packages/jx) [![Documentation](https://img.shields.io/badge/-Documentation-blueviolet)](https://hexdocs.pm/jx)

Jx is a library for Elixir that brings binding of functions to variables to pattern matching. Its high-level features are:

  * Searching for function values to bind to specially marked variables (prefixed with `j`) in match expressions such as `"j" = jx.([106])`

## Installation

The package can be installed by adding `jx` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:jx, "~> 0.3"}
  ]
end
```

## Examples

```elixir
iex> require Jx; import Jx
iex> j [[2, 0, a, b], [1, a, b]] = [jx.(2023), jx.(123)]
#Jx<a=2, b=3, jx=&Integer.digits/1>
iex> jx.(a * 10 + b)
[2, 3]
```