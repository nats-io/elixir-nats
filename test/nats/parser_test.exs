# this is somewhat generated. don't touch.

defmodule Nats.ParserTest do
	use ExUnit.Case, async: true

	test "PING/PONG/OK/ERR parsing" do
		verb = Nats.Parser.parse("PING\r\n")
		assert verb == {:ok, {:ping}}
		
		out = Nats.Parser.encode(verb)
		assert out == "PING\r\n"
		
		verb = Nats.Parser.parse("PONG\r\n")
		assert verb == {:ok, {:pong}}

		out = Nats.Parser.encode(verb)
		assert out == "PONG\r\n"
		
		verb = Nats.Parser.parse("+OK\r\n")
		assert verb == {:ok, {:ok}}

		out = Nats.Parser.encode(verb)
		assert out == "+OK\r\n"
		
    verb = Nats.Parser.parse("-ERR abc\r\n")
    assert verb == {:ok, {:err, "abc"}}

		out = Nats.Parser.encode(verb)
		assert out == "-ERR abc\r\n"
		
		# missing arg...
    verb = {stat, details} = Nats.Parser.parse("-ERR\r\n")
		assert stat == :error
    assert verb == {stat, details}
    verb = Nats.Parser.parse("-ERR hello world\r\n")
    assert verb == {:ok, {:err, "hello world"}}
	end
	
	test "INFO/CONNECT parsing" do

		{ v, _rest } = Nats.Parser.parse("INFO \r\n")
		assert v == :error

    { v, _rest } = Nats.Parser.parse("INFO \"false\" \r\n")
		assert v == :error

    { v, _rest } = Nats.Parser.parse("INFO false \r\n")
		assert v == :error

    { v, _rest } = Nats.Parser.parse("INFO \"FFFF\" \r\n")
		assert v == :error

    { v, _rest } = Nats.Parser.parse("INFO 456 \r\n")
		assert v == :error
		
    { v, _rest } = Nats.Parser.parse("INFO true\r\n")
		assert v == :error

    { v, _rest } = Nats.Parser.parse("INFO {\"key\":true}\r\n")
		assert v == :ok
#		IO.puts inspect(_rest)

    { v, _rest } = Nats.Parser.parse("INFO { \"key\":true, \"embed\": {\"a\": [\"b\",\"c\", 123] } }\r\n")
#		IO.puts inspect(_rest)
		assert v == :ok

    v = Nats.Parser.parse("INFO {}\r\n")
		out = Nats.Parser.encode(v)
		assert out == "INFO {}\r\n"

    v = Nats.Parser.parse("INFO { \"key\":true}\r\n")
		out = Nats.Parser.encode(v)
		assert out == "INFO {\"key\": true}\r\n"

    v = Nats.Parser.parse("INFO { \"k1\":true, \"k2\": false}\r\n")
		out = Nats.Parser.encode(v)
		assert out == "INFO {\"k1\": true, \"k2\": false}\r\n"
		
    { v, _rest } = Nats.Parser.parse("CONNECT {\"key\":true}\r\n")
		assert v == :ok
#		IO.puts inspect(_rest)

    { v, rest } = Nats.Parser.parse("INFO {\"a\":{\"b\":{\"c\":\"zebra\"}}}\r\n")
#		IO.puts inspect(rest)
		assert v == :ok
		{ verb, json } = rest
		assert verb == :info
		assert json["a"]["b"]["c"] == "zebra"

		v = Nats.Parser.parse("INFO {\"a\":{\"b\":{\"c\":\"zebra\"}}}\r\n")
		_out = Nats.Parser.encode(v)
	end
	
	test "UNSUB parsing" do
		{ v, rest } = Nats.Parser.parse("UNSUB subj\r\n")
		assert v == :ok
		assert rest == {:unsub, "subj", nil}

		{ v, rest } = Nats.Parser.parse("UNSUB subj 10\r\n")
		assert v == :ok
		assert rest == {:unsub, "subj", 10}

		{ v, _rest } = Nats.Parser.parse("UNSUB subj bad\r\n")
		assert v == :error
	end
	
	test "SUB parsing" do
		v = Nats.Parser.parse("SUB subj sid\r\n")
		assert v == {:ok, {:sub, "subj", nil, "sid"}}

		out = Nats.Parser.encode(v)
		assert out == "SUB subj sid\r\n"

		
		v = Nats.Parser.parse("SUB subj q sid\r\n")
		assert v == {:ok, {:sub, "subj", "q", "sid"}}

    out = Nats.Parser.encode(v)
		assert out == "SUB subj q sid\r\n"
		
		{ v, _rest } = Nats.Parser.parse("SUB bad\r\n")
		assert v == :error

	end

	test "PUB parsing" do
		v = Nats.Parser.parse("PUB subj 0\r\n")
		assert v == {:ok, {:pub, "subj", nil, 0}}

    out = Nats.Parser.encode(v)
		assert out == "PUB subj 0\r\n"

		v = Nats.Parser.parse("PUB subj ret 18\r\n")
		assert v == {:ok, {:pub, "subj", "ret", 18}}

    out = Nats.Parser.encode(v)
		assert out == "PUB subj ret 18\r\n"
		
		v = Nats.Parser.parse("PUB subj ret 5\r\n")
		assert v == {:ok, {:pub, "subj", "ret", 5}}

		v = Nats.Parser.parse("PUB subj ret 10\r\n")
		assert v == {:ok, {:pub, "subj", "ret", 10}}

		{ v, _rest } = Nats.Parser.parse("PUB subj ret -1\r\n")
		assert v == :error
		
		{ v, _rest } = Nats.Parser.parse("PUB sub ret zz\r\n")
		assert v == :error
		{ v, _rest } = Nats.Parser.parse("PUB sub zz\r\n")
		assert v == :error
		{ v, _rest } = Nats.Parser.parse("PUB zz\r\n")
		assert v == :error
		{ v, _rest } = Nats.Parser.parse("PUB \r\n")
		assert v == :error

		{ v, _rest } = Nats.Parser.parse("PUB sub ret 0\r\n")
		assert v == :error
		{ v, _rest } = Nats.Parser.parse("PUB sub 0\r\n")
		assert v == :error
		{ v, _rest } = Nats.Parser.parse("PUB 0\r\n")
		assert v == :error
		{ v, _rest } = Nats.Parser.parse("PUB \r\n")
		assert v == :error
	end

	test "MSG parsing" do
		v = Nats.Parser.parse("MSG subj sid 0\r\n")
		assert v == {:ok, {:msg, "subj", "sid", nil, 0}}

    out = Nats.Parser.encode(v)
		assert out == "MSG subj sid 0\r\n"
		
		v = Nats.Parser.parse("MSG subj sid ret 19\r\n")
		assert v == {:ok, {:msg, "subj", "sid", "ret", 19}}

    out = Nats.Parser.encode(v)
		assert out == "MSG subj sid ret 19\r\n"
		
		{ v, _rest } = Nats.Parser.parse("MSG subj sid ret bad\r\n")
		assert v == :error
		{ v, _rest } = Nats.Parser.parse("MSG subj sid ret -1\r\n")
		assert v == :error
		{ v, _rest } = Nats.Parser.parse("MSG subj zz\r\n")
		assert v == :error
		{ v, _rest } = Nats.Parser.parse("MSG zz\r\n")
		assert v == :error
		{ v, _rest } = Nats.Parser.parse("MSG \r\n")
		assert v == :error

		{ v, _rest } = Nats.Parser.parse("MSG sub ret 0\r\n")
		assert v == :error
		{ v, _rest } = Nats.Parser.parse("MSG sub 0\r\n")
		assert v == :error
		{ v, _rest } = Nats.Parser.parse("MSG 0\r\n")
		assert v == :error
		{ v, _rest } = Nats.Parser.parse("MSG \r\n")
		assert v == :error
	end
end

