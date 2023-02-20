defmodule Jx.CatalogTest do
  use ExUnit.Case
  doctest Jx.Catalog

  describe "Jx.Catalog.*" do
    test "value of module docs" do
      assert {:docs_v1, 1, :elixir, "text/markdown", :hidden, %{},
        [{{:function, :j, 1}, 1, ["j(" <> _], :none, %{}}]
      } = Code.fetch_docs(Jx.Catalog.Kernel)
    end
  end
end