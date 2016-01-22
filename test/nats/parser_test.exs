# this is somewhat generated. don't touch.

defmodule Nats.ParserTest do
	use ExUnit.Case, async: true

	test "PING/PONG/OK/ERR parsing" do
		{:ok, verb, [], _}  = Nats.Parser.parse("PING\r\n")
		assert verb == {:ping}
		
		out = Nats.Parser.encode(verb)
		assert out == "PING\r\n"
		
		{:ok, verb, [], _} = Nats.Parser.parse("PONG\r\n")
		assert verb == {:pong}

		out = Nats.Parser.encode(verb)
		assert out == "PONG\r\n"
		
		{:ok, verb, [], _} = Nats.Parser.parse("+OK\r\n")
		assert verb == {:ok}

		out = Nats.Parser.encode(verb)
		assert out == "+OK\r\n"
		
    {:ok, verb, [], _} = Nats.Parser.parse("-ERR abc\r\n")
    assert verb == {:err, "abc"}

		out = Nats.Parser.encode(verb)
		assert out == "-ERR abc\r\n"
		
		# missing arg...
    {:error, _details, _} = Nats.Parser.parse("-ERR\r\n")
#		IO.puts details
    {:ok, verb, [], _} = Nats.Parser.parse("-ERR hello world\r\n")
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

    {:ok, { v, _rest}, [], _} = Nats.Parser.parse("INFO {\"key\":true}\r\n")
		assert v == :info
#		IO.puts inspect(_rest)

    {:ok, { v, _rest }, [], _} = Nats.Parser.parse("INFO { \"key\":true, \"embed\": {\"a\": [\"b\",\"c\", 123] } }\r\n")
#		IO.puts inspect(_rest)
		assert v == :info

    {:ok, v, [], _} = Nats.Parser.parse("INFO {}\r\n")
		out = Nats.Parser.encode(v)
		assert out == "INFO {}\r\n"

    {:ok, v, [], _} = Nats.Parser.parse("INFO { \"key\":true}\r\n")
		out = Nats.Parser.encode(v)
		assert out == "INFO {\"key\": true}\r\n"

    {:ok, v, [], _} = Nats.Parser.parse("INFO { \"k1\":true, \"k2\": false}\r\n")
		out = Nats.Parser.encode(v)
		assert out == "INFO {\"k1\": true, \"k2\": false}\r\n"
		
    {:ok, {v, _rest}, [], _} = Nats.Parser.parse("CONNECT {\"key\":true}\r\n")
		assert v == :connect
#		IO.puts inspect(_rest)

    {:ok, {verb, json}, [], _} =
			Nats.Parser.parse("INFO {\"a\":{\"b\":{\"c\":\"zebra\"}}}\r\n")
#		IO.puts inspect(rest)
		assert verb == :info
		assert json["a"]["b"]["c"] == "zebra"

		{:ok, v, [], _} = Nats.Parser.parse("INFO {\"a\":{\"b\":{\"c\":\"zebra\"}}}\r\n")
		_out = Nats.Parser.encode(v)
	end
	
	test "UNSUB parsing" do
		{:ok, rest, [], _} =  Nats.Parser.parse("UNSUB subj\r\n")
		assert rest == {:unsub, "subj", nil}

		{ v, rest, [], _ } = Nats.Parser.parse("UNSUB subj 10\r\n")
		assert v == :ok
		assert rest == {:unsub, "subj", 10}

		{ v, _rest, _ } = Nats.Parser.parse("UNSUB subj bad\r\n")
		assert v == :error
	end
	
	test "SUB parsing" do
		{:ok, verb, [], _} = Nats.Parser.parse("SUB subj sid\r\n")
		assert verb == {:sub, "subj", nil, "sid"}
		out = Nats.Parser.encode(verb)
		assert out == "SUB subj sid\r\n"

		
		{:ok, verb, [], _} = Nats.Parser.parse("SUB subj q sid\r\n")
		assert verb == {:sub, "subj", "q", "sid"}

    out = Nats.Parser.encode(verb)
		assert out == "SUB subj q sid\r\n"
		
		{ v, _rest, _ } = Nats.Parser.parse("SUB bad\r\n")
		assert v == :error

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
	end

	test "MSG parsing" do
		v = Nats.Parser.parse("MSG subj sid 0\r\n\r\n")
#		IO.puts inspect(v)
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

