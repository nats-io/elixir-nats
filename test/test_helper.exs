# Copyright 2016 Apcera Inc. All rights reserved.
#ExUnit.configure exclude: [disabled: true]
ExUnit.start

defmodule TestHelper do
  defmacro assert_parse_error(binary) do
    quote do
      { v, _rest, _ } = Nats.Parser.parse(unquote(binary))
      assert v == :error
    end
  end

  defmacro assert_verb_parse_encode(binary, expected_verb) do
    quote bind_quoted: [
        binary: binary,
        expected_verb: expected_verb
      ] do
      assert {:ok, verb, "", _} = Nats.Parser.parse(binary)
      assert verb == expected_verb
      out = encode(verb)
      assert out == binary
    end
  end
end
