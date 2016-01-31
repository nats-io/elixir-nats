# Copyright 2016 Apcera Inc. All rights reserved.
# this is somewhat generated. don't touch.
defmodule Nats.ParserTest do
  use ExUnit.Case, async: true

  defp encode(x),             do: Enum.join(Nats.Parser.encode(x), "")
  defp parse(binary),         do: Nats.Parser.parse(binary)
  defp parse(state, binary),  do: Nats.Parser.parse(state, binary)

  test "PING/PONG/OK/ERR parsing" do
    {:ok, verb, "", _}  = parse("PING\r\n")
    assert verb == {:ping}

    out = encode(verb)

    assert out == "PING\r\n"

    {:ok, verb, "", _} = parse("PONG\r\n")
    assert verb == {:pong}

    out = encode(verb)
    assert out == "PONG\r\n"

    {:ok, verb, "", _} = parse("+OK\r\n")
    assert verb == {:ok}

    out = encode(verb)
    assert out == "+OK\r\n"

    {:ok, verb, "", _} = parse("-ERR abc\r\n")
    assert verb == {:err, "abc"}

    out = encode(verb)
    assert out == "-ERR abc\r\n"

    # missing arg...
    {:error, _details, _} = parse("-ERR\r\n")
    #  IO.puts details
    {:ok, verb, "", _} = parse("-ERR hello world\r\n")
    assert verb == {:err, "hello world"}
  end

  test "INFO/CONNECT parsing" do

    { v, _rest, _ } = parse("INFO \r\n")
    assert v == :error

    { v, _rest, _ } = parse("INFO \"false\" \r\n")
    assert v == :error

    { v, _rest, _ } = parse("INFO false \r\n")
    assert v == :error

    { v, _rest, _ } = parse("INFO \"FFFF\" \r\n")
    assert v == :error

    { v, _rest, _ } = parse("INFO 456 \r\n")
    assert v == :error

    { v, _rest, _ } = parse("INFO true\r\n")
    assert v == :error

    {:ok, { v, _rest}, "", _} = parse("INFO {\"key\":true}\r\n")
    assert v == :info
    #  IO.puts inspect(_rest)

    to_p = "INFO { \"key\":true, \"embed\": {\"a\": [\"b\",\"c\", 123] } }\r\n"
    {:ok, { v, _rest }, "", _} = parse(to_p)
    #  IO.puts inspect(_rest)
    assert v == :info

    {:ok, v, "", _} = parse("INFO {}\r\n")
    out = encode(v)
    assert out == "INFO {}\r\n"

    {:ok, v, "", _} = parse("INFO { \"key\":true}\r\n")
    out = encode(v)
    assert out == "INFO {\"key\": true}\r\n"

    {:ok, v, "", _} =
      parse("INFO { \"k1\":true, \"k2\": false}\r\n")
    out = encode(v)
    assert out == "INFO {\"k1\": true, \"k2\": false}\r\n"

    {:ok, {v, _rest}, "", _} = parse("CONNECT {\"key\":true}\r\n")
    assert v == :connect
    #  IO.puts inspect(_rest)

    {:error, _, _} = parse("INFO []\r\n")
    {:error, _, _} = parse("INFO [\r\n")
    {:error, _, _} = parse("INFO @\r\n")
    {:error, _, _} = parse("INFO [false, true,false,]\r\n")


    {:cont, _howmany, state} = parse("CON")
    {:ok, {:connect, %{}}, "", _} = parse(state, "NECT {}\r\n")

    {:ok, _, "+OK\r\n", _} = parse("PUB S S 1\r\n1\r\n+OK\r\n")
    {:ok, _, "", _} = parse("PUB S S 1\r\n1\r\n")

    {:error, _, _} = parse("PUB S S 1\r\n1\rZ+OK\r\n")


    {:ok, {verb, json}, "", _} =
      parse("INFO {\"a\":{\"b\":{\"c\":\"zebra\"}}}\r\n")
    #  IO.puts inspect(rest)
    assert verb == :info
    assert json["a"]["b"]["c"] == "zebra"

    {:ok, verb, "", _} =
      parse("INFO {\"a\": [true,false,null,\"abc\",[1],2.2,[]]}\r\n")
    _out = encode(verb)
#    IO.puts "NATS: verb -> #{inspect(verb)}"
#    IO.puts "NATS: out ->  #{inspect(out)}"

    {:ok, v, "", _} =
      parse("INFO {\"a\":{\"b\":{\"c\":\"zebra\"}}}\r\n")
    _out = encode(v)

    {:ok, v, "", _} =
      parse("CONNECT {\"a\":{\"b\":{\"c\":\"zebra\"}}}\r\n")
    _out = encode(v)
  end

  test "UNSUB parsing" do
    {:ok, rest, "", _} =  parse("UNSUB sid\r\n")
    assert rest == {:unsub, "sid", nil}
    out = encode(rest)
    assert out == "UNSUB sid\r\n"

    { v, rest, "", _ } = parse("UNSUB sid 10\r\n")
    assert v == :ok
    assert rest == {:unsub, "sid", 10}
    out = encode(rest)
    assert out == "UNSUB sid 10\r\n"

    { v, _rest, _ } = parse("UNSUB sid bad\r\n")
    assert v == :error
  end

  test "SUB parsing" do
    {:ok, verb, "", _} = parse("SUB subj sid\r\n")
    assert verb == {:sub, "subj", nil, "sid"}
    out = encode(verb)
    assert out == "SUB subj sid\r\n"


    {:ok, verb, "", _} = parse("SUB subj q sid\r\n")
    assert verb == {:sub, "subj", "q", "sid"}

    out = encode(verb)
    assert out == "SUB subj q sid\r\n"

    { v, _rest, _ } = parse("SUB bad\r\n")
    assert v == :error

    { :ok, sub, _, _ } = parse("SUB S s\r\n")
    res = encode(sub)
    assert res == <<"SUB S s\r\n">>

    { :ok, sub, _, _ } = parse("SUB S Q s\r\n")
    res = encode(sub)
    assert res == <<"SUB S Q s\r\n">>
  end

  test "PUB parsing" do
    {:ok, verb, "", _} =  parse("PUB subj 0\r\n\r\n")
    assert verb == {:pub, "subj", nil, ""}

    out = encode({:pub, "subj", nil, "1234"})
    assert out == "PUB subj 4\r\n1234\r\n"

    {:ok, verb, "", _} = parse("PUB subj ret 4\r\nnats\r\n")
    assert verb == {:pub, "subj", "ret", "nats"}


    out = encode({:pub, "subj", "ret", "io"})
    assert out == "PUB subj ret 2\r\nio\r\n"

    {:ok, verb, "", _} = parse("PUB subj ret 5\r\nnats!\r\n")
    assert verb == {:pub, "subj", "ret", "nats!"}

    {:ok, verb, "", _} = parse("PUB subj ret 10\r\nhello nats\r\n")
    assert verb == {:pub, "subj", "ret", "hello nats"}

    { v, _rest, _ } = parse("PUB subj ret -1\r\n")
    assert v == :error

    { v, _rest, _ } = parse("PUB sub ret zz\r\n")
    assert v == :error
    { v, _rest, _ } = parse("PUB sub zz\r\n")
    assert v == :error
    { v, _rest, _ } = parse("PUB zz\r\n")
    assert v == :error
    { v, _rest, _ } = parse("PUB \r\n")
    assert v == :error

    { v, _rest, _ } = parse("PUB sub ret 0\r\n")
    assert v == :cont
    { v, _rest, _ } = parse("PUB sub 0\r\n")
    assert v == :cont
    { v, _rest, _ } = parse("PUB 0\r\n")
    assert v == :error
    { v, _rest, _ } = parse("PUB \r\n")
    assert v == :error

    { :ok, pub, _, _ } = parse("PUB S 0\r\n\r\n")
    res = encode(pub)
    assert res == <<"PUB S 0\r\n\r\n">>

    { :ok, pub, _, _ } = parse("PUB S R 0\r\n\r\n")
    res = encode(pub)
    assert res == <<"PUB S R 0\r\n\r\n">>
  end

  test "MSG parsing" do
    v = parse("MSG subj sid 0\r\n\r\n")
    #  IO.puts inspect(v)
    {:ok, verb, "", _} = v
    assert verb == {:msg, "subj", "sid", nil, ""}

    out = encode(verb)
    assert out == "MSG subj sid 0\r\n\r\n"

    {:ok, verb, "", _} = parse("MSG subj sid ret 4\r\nnats\r\n")
    assert verb == {:msg, "subj", "sid", "ret", "nats"}

    out = encode(verb)
    assert out == "MSG subj sid ret 4\r\nnats\r\n"

    { v, _rest, _ } = parse("MSG subj sid ret bad\r\n")
    assert v == :error
    { v, _rest, _ } = parse("MSG subj sid ret -1\r\n")
    assert v == :error
    { v, _rest, _ } = parse("MSG subj zz\r\n")
    assert v == :error
    { v, _rest, _ } = parse("MSG zz\r\n")
    assert v == :error
    { v, _rest, _ } = parse("MSG \r\n")
    assert v == :error

    { :ok, msg, _, _ } = parse("MSG S s 0\r\n\r\n")
    res = encode(msg)
    assert res == <<"MSG S s 0\r\n\r\n">>

    { :ok, msg, _, _ } = parse("MSG S s R 0\r\n\r\n")
    res = encode(msg)
    assert res == <<"MSG S s R 0\r\n\r\n">>

    { v, _rest, _ } = parse("MSG sub ret 0\r\n")
    assert v == :cont
    { v, _rest, _ } = parse("MSG sub 0\r\n")
    assert v == :error
    { v, _rest, _ } = parse("MSG 0\r\n")
    assert v == :error
    { v, _rest, _ } = parse("MSG \r\n")
    assert v == :error
  end

  test "continuation testing to address GH-18" do
    # Thanks @mindreframer !
    # See https://github.com/nats-io/elixir-nats/issues/18


    {:cont, _, state} = parse("CO")
    {:ok, {:connect, %{}}, "", _} = parse(state, "NNECT {}\r\n")

    {:cont, _, state} = parse("CON")
    {:ok, {:connect, %{}}, "", _} = parse(state, "NECT {}\r\n")

    {:cont, _, state} = parse("CONN")
    {:ok, {:connect, %{}}, "", _} = parse(state, "ECT {}\r\n")

    {:cont, _, state} = parse("CONNE")
    {:ok, {:connect, %{}}, "", _} = parse(state, "CT {}\r\n")

    {:cont, _, state} = parse("CONNE")
    {:ok, {:connect, %{}}, "", _} = parse(state, "CT {}\r\n")

    {:cont, _, state} = parse("-E")
    {:cont, _, state} = parse(state, "R")
    {:cont, _, state} = parse(state, "R")
    {:cont, _, state} = parse(state, "")
    {:cont, _, state} = parse(state, " ")
    {:cont, _, state} = parse(state, " ")
    {:cont, _, state} = parse(state, "")
    msg = "SOME ERROR"
    {:cont, _, state} = parse(state, msg)
    {:cont, _, state} = parse(state, "")
    {:cont, _, state} = parse(state, "\r")
    {:cont, _, state} = parse(state, "")
    msg = " " <> msg
    {:ok, {:err, ^msg}, "", _state} = parse(state, "\n")

    {:cont, _, state} = parse("MSG ")
    {:cont, _, state} = parse(state, "")
    {:cont, _, state} = parse(state, "s")
    {:cont, _, state} = parse(state, "")
    {:cont, _, state} = parse(state, "u")
    {:cont, _, state} = parse(state, "")
    {:cont, _, state} = parse(state, "b")
    {:cont, _, state} = parse(state, "")
    {:cont, _, state} = parse(state, " ")
    {:cont, _, state} = parse(state, " ")
    {:cont, _, state} = parse(state, " SID1.")
    {:cont, _, state} = parse(state, "SID2.")
    {:cont, _, state} = parse(state, "")
    {:cont, _, state} = parse(state, "S")
    {:cont, _, state} = parse(state, "I")
    {:cont, _, state} = parse(state, "D3")
    {:cont, _, state} = parse(state, " ")
    {:cont, _, state} = parse(state, "")
    {:cont, _, state} = parse(state, "\t")
    {:cont, _, state} = parse(state, " \t ")
    {:cont, _, state} = parse(state, "4")
    {:cont, _, state} = parse(state, "")
    {:cont, _, state} = parse(state, " ")
    {:cont, _, state} = parse(state, "\t")
    {:cont, _, state} = parse(state, "")
    {:cont, _, state} = parse(state, "\r")
    {:cont, _, state} = parse(state, "")
    {:cont, _, state} = parse(state, "\n")
    {:cont, _, state} = parse(state, "")
    {:cont, _, state} = parse(state, "")
    {:cont, _, state} = parse(state, "na")
    {:cont, _, state} = parse(state, "")
    {:cont, _, state} = parse(state, "t")
    {:cont, _, state} = parse(state, "")
    {:cont, _, state} = parse(state, "s")
    {:cont, _, state} = parse(state, "")
    {:cont, _, state} = parse(state, "\r")
    {:cont, _, state} = parse(state, "")
    {:ok, verb, "ABC", _state} = parse(state, "\nABC")
    assert verb === {:msg, "sub", "SID1.SID2.SID3", nil, "nats"}
  end
end

