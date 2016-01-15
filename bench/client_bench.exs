
defmodule ClientBench do
  use Benchfella

  @list Enum.to_list(1..1000)

  bench "hello list" do
    Enum.reverse @list
  end
  
  bench "do it", [str: gen_string()] do
    String.reverse(str)
  end
  defp gen_string() do
    String.duplicate("def", 1024)
  end
end
