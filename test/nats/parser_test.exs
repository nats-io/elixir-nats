# Copyright 2016 Apcera Inc. All rights reserved.
# this is somewhat generated. don't touch.
defmodule Nats.ParserTest do
  use ExUnit.Case, async: true

  test "PING/PONG/OK/ERR parsing" do
    {:ok, verb, "", _}  = Nats.Parser.parse("PING\r\n")
    assert verb == {:ping}
    
    out = Nats.Parser.encode(verb)
    assert out == "PING\r\n"
    
    {:ok, verb, "", _} = Nats.Parser.parse("PONG\r\n")
    assert verb == {:pong}

    out = Nats.Parser.encode(verb)
    assert out == "PONG\r\n"
    
    {:ok, verb, "", _} = Nats.Parser.parse("+OK\r\n")
    assert verb == {:ok}

    out = Nats.Parser.encode(verb)
    assert out == "+OK\r\n"
    
    {:ok, verb, "", _} = Nats.Parser.parse("-ERR abc\r\n")
    assert verb == {:err, "abc"}

    out = Nats.Parser.encode(verb)
    assert out == "-ERR abc\r\n"
    
    # missing arg...
    {:error, _details, _} = Nats.Parser.parse("-ERR\r\n")
    #  IO.puts details
    {:ok, verb, "", _} = Nats.Parser.parse("-ERR hello world\r\n")
    assert verb == {:err, "hello world"}
  end
 
  test "INFO/CONNECT parsing" do

    { v, _rest, _ } = Nats.Parser.parse("INFO \r\n")
    assert v == :error

    { v, _rest, _ } = Nats.Parser.parse("INFO \"false\" \r\n")
    assert v == :error

    { v, _rest, _ } = Nats.Parser.parse("INFO false \r\n")
    assert v == :error

    { v, _rest, _ } = Nats.Parser.parse("INFO \"FFFF\" \r\n")
    assert v == :error

    { v, _rest, _ } = Nats.Parser.parse("INFO 456 \r\n")
    assert v == :error
    
    { v, _rest, _ } = Nats.Parser.parse("INFO true\r\n")
    assert v == :error

    {:ok, { v, _rest}, "", _} = Nats.Parser.parse("INFO {\"key\":true}\r\n")
    assert v == :info
    #  IO.puts inspect(_rest)

    to_p = "INFO { \"key\":true, \"embed\": {\"a\": [\"b\",\"c\", 123] } }\r\n"
    {:ok, { v, _rest }, "", _} = Nats.Parser.parse(to_p)
    #  IO.puts inspect(_rest)
    assert v == :info

    {:ok, v, "", _} = Nats.Parser.parse("INFO {}\r\n")
    out = Nats.Parser.encode(v)
    assert out == "INFO {}\r\n"

    {:ok, v, "", _} = Nats.Parser.parse("INFO { \"key\":true}\r\n")
    out = Nats.Parser.encode(v)
    assert out == "INFO {\"key\": true}\r\n"

    {:ok, v, "", _} =
      Nats.Parser.parse("INFO { \"k1\":true, \"k2\": false}\r\n")
    out = Nats.Parser.encode(v)
    assert out == "INFO {\"k1\": true, \"k2\": false}\r\n"
    
    {:ok, {v, _rest}, "", _} = Nats.Parser.parse("CONNECT {\"key\":true}\r\n")
    assert v == :connect
    #  IO.puts inspect(_rest)

    {:error, _, _} = Nats.Parser.parse("INFO []\r\n")
    {:error, _, _} = Nats.Parser.parse("INFO [\r\n")
    {:error, _, _} = Nats.Parser.parse("INFO @\r\n")
    {:error, _, _} = Nats.Parser.parse("INFO [false, true,false,]\r\n")


    {:cont, _howmany, state} = Nats.Parser.parse("CON")
    {:ok, {:connect, %{}}, "", _} = Nats.Parser.parse(state, "NECT {}\r\n")

    {:ok, _, "+OK\r\n", _} = Nats.Parser.parse("PUB S S 1\r\n1\r\n+OK\r\n")
    {:ok, _, "", _} = Nats.Parser.parse("PUB S S 1\r\n1\r\n")

    {:error, _, _} = Nats.Parser.parse("PUB S S 1\r\n1\rZ+OK\r\n")
    
    
    {:ok, {verb, json}, "", _} =
      Nats.Parser.parse("INFO {\"a\":{\"b\":{\"c\":\"zebra\"}}}\r\n")
    #  IO.puts inspect(rest)
    assert verb == :info
    assert json["a"]["b"]["c"] == "zebra"

    {:ok, verb, "", _} =
      Nats.Parser.parse("INFO {\"a\": [true,false,null,\"abc\",[1],2.2,[]]}\r\n")
    _out = Nats.Parser.encode(verb)
#    IO.puts "NATS: verb -> #{inspect(verb)}"
#    IO.puts "NATS: out ->  #{inspect(out)}"
    
    {:ok, v, "", _} =
      Nats.Parser.parse("INFO {\"a\":{\"b\":{\"c\":\"zebra\"}}}\r\n")
    _out = Nats.Parser.encode(v)

    {:ok, v, "", _} =
      Nats.Parser.parse("CONNECT {\"a\":{\"b\":{\"c\":\"zebra\"}}}\r\n")
    _out = Nats.Parser.encode(v)
  end
 
  test "UNSUB parsing" do
    {:ok, rest, "", _} =  Nats.Parser.parse("UNSUB sid\r\n")
    assert rest == {:unsub, "sid", nil}

    { v, rest, "", _ } = Nats.Parser.parse("UNSUB sid 10\r\n")
    assert v == :ok
    assert rest == {:unsub, "sid", 10}

    { v, _rest, _ } = Nats.Parser.parse("UNSUB sid bad\r\n")
    assert v == :error
  end
 
  test "SUB parsing" do
    {:ok, verb, "", _} = Nats.Parser.parse("SUB subj sid\r\n")
    assert verb == {:sub, "subj", nil, "sid"}
    out = Nats.Parser.encode(verb)
    assert out == "SUB subj sid\r\n"

    
    {:ok, verb, "", _} = Nats.Parser.parse("SUB subj q sid\r\n")
    assert verb == {:sub, "subj", "q", "sid"}

    out = Nats.Parser.encode(verb)
    assert out == "SUB subj q sid\r\n"
    
    { v, _rest, _ } = Nats.Parser.parse("SUB bad\r\n")
    assert v == :error

    { :ok, sub, _, _ } = Nats.Parser.parse("SUB S s\r\n")
    res = Nats.Parser.encode(sub)
    assert res == <<"SUB S s\r\n">>

    { :ok, sub, _, _ } = Nats.Parser.parse("SUB S Q s\r\n")
    res = Nats.Parser.encode(sub)
    assert res == <<"SUB S Q s\r\n">>
  end

  test "PUB parsing" do
    {:ok, verb, "", _} =  Nats.Parser.parse("PUB subj 0\r\n\r\n")
    assert verb == {:pub, "subj", nil, ""}

    out = Nats.Parser.encode({:pub, "subj", nil, "1234"})
    assert out == "PUB subj 4\r\n1234\r\n"

    {:ok, verb, "", _} = Nats.Parser.parse("PUB subj ret 4\r\nnats\r\n")
    assert verb == {:pub, "subj", "ret", "nats"}

    
    out = Nats.Parser.encode({:pub, "subj", "ret", "io"})
    assert out == "PUB subj ret 2\r\nio\r\n"
    
    {:ok, verb, "", _} = Nats.Parser.parse("PUB subj ret 5\r\nnats!\r\n")
    assert verb == {:pub, "subj", "ret", "nats!"}

    {:ok, verb, "", _} = Nats.Parser.parse("PUB subj ret 10\r\nhello nats\r\n")
    assert verb == {:pub, "subj", "ret", "hello nats"}

    { v, _rest, _ } = Nats.Parser.parse("PUB subj ret -1\r\n")
    assert v == :error
    
    { v, _rest, _ } = Nats.Parser.parse("PUB sub ret zz\r\n")
    assert v == :error
    { v, _rest, _ } = Nats.Parser.parse("PUB sub zz\r\n")
    assert v == :error
    { v, _rest, _ } = Nats.Parser.parse("PUB zz\r\n")
    assert v == :error
    { v, _rest, _ } = Nats.Parser.parse("PUB \r\n")
    assert v == :error

    { v, _rest, _ } = Nats.Parser.parse("PUB sub ret 0\r\n")
    assert v == :error
    { v, _rest, _ } = Nats.Parser.parse("PUB sub 0\r\n")
    assert v == :error
    { v, _rest, _ } = Nats.Parser.parse("PUB 0\r\n")
    assert v == :error
    { v, _rest, _ } = Nats.Parser.parse("PUB \r\n")
    assert v == :error

    { :ok, pub, _, _ } = Nats.Parser.parse("PUB S 0\r\n\r\n")
    res = Nats.Parser.encode(pub)
    assert res == <<"PUB S 0\r\n\r\n">>
    
    { :ok, pub, _, _ } = Nats.Parser.parse("PUB S R 0\r\n\r\n")
    res = Nats.Parser.encode(pub)
    assert res == <<"PUB S R 0\r\n\r\n">>
  end

  test "MSG parsing" do
    v = Nats.Parser.parse("MSG subj sid 0\r\n\r\n")
    #  IO.puts inspect(v)
    {:ok, verb, "", _} = v
    assert verb == {:msg, "subj", "sid", nil, ""}

    out = Nats.Parser.encode(verb)
    assert out == "MSG subj sid 0\r\n\r\n"
    
    {:ok, verb, "", _} = Nats.Parser.parse("MSG subj sid ret 4\r\nnats\r\n")
    assert verb == {:msg, "subj", "sid", "ret", "nats"}

    out = Nats.Parser.encode(verb)
    assert out == "MSG subj sid ret 4\r\nnats\r\n"
    
    { v, _rest, _ } = Nats.Parser.parse("MSG subj sid ret bad\r\n")
    assert v == :error
    { v, _rest, _ } = Nats.Parser.parse("MSG subj sid ret -1\r\n")
    assert v == :error
    { v, _rest, _ } = Nats.Parser.parse("MSG subj zz\r\n")
    assert v == :error
    { v, _rest, _ } = Nats.Parser.parse("MSG zz\r\n")
    assert v == :error
    { v, _rest, _ } = Nats.Parser.parse("MSG \r\n")
    assert v == :error

    { :ok, msg, _, _ } = Nats.Parser.parse("MSG S s 0\r\n\r\n")
    res = Nats.Parser.encode(msg)
    assert res == <<"MSG S s 0\r\n\r\n">>
    
    { :ok, msg, _, _ } = Nats.Parser.parse("MSG S s R 0\r\n\r\n")
    res = Nats.Parser.encode(msg)
    assert res == <<"MSG S s R 0\r\n\r\n">>
    
    { v, _rest, _ } = Nats.Parser.parse("MSG sub ret 0\r\n")
    assert v == :error
    { v, _rest, _ } = Nats.Parser.parse("MSG sub 0\r\n")
    assert v == :error
    { v, _rest, _ } = Nats.Parser.parse("MSG 0\r\n")
    assert v == :error
    { v, _rest, _ } = Nats.Parser.parse("MSG \r\n")
    assert v == :error
  end
end

