defmodule Jx.CatalogTest do
  use ExUnit.Case
  doctest Jx.Catalog

  describe "Jx.Catalog.*" do
    test "value of module docs" do
      docs = Code.fetch_docs(Jx.Catalog.Kernel)
      assert docs === {:docs_v1, 1, :elixir, "text/markdown", :hidden, %{},
        [{{:function, :j, 1}, 1, ["j(a)"], :none, %{}}]
      }
    end
  end
end