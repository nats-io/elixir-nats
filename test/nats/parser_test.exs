# Copyright 2016 Apcera Inc. All rights reserved.
# this is somewhat generated. don't touch.
defmodule Nats.ParserTest do
  use ExUnit.Case, async: true
  import TestHelper

  defp encode(x),             do: Nats.Parser.flat_encode(x)
  defp parse(binary),         do: Nats.Parser.parse(binary)
  defp parse(state, binary),  do: Nats.Parser.parse(state, binary)

  test "PING/PONG/OK/ERR parsing" do
    assert_verb_parse_encode("PING\r\n", {:ping})
    assert_verb_parse_encode("PONG\r\n", {:pong})
    assert_verb_parse_encode("+OK\r\n", {:ok})
    assert_verb_parse_encode("-ERR abc\r\n", {:err, "abc"})
    assert_verb_parse_encode("-ERR hello world\r\n", {:err, "hello world"})

    # missing arg...
    assert_parse_error("-ERR\r\n")
  end

  test "INFO/CONNECT parsing" do
    assert_parse_error("INFO \r\n")
    assert_parse_error("INFO \"false\" \r\n")
    assert_parse_error("INFO false \r\n")
    assert_parse_error("INFO \"FFFF\" \r\n")
    assert_parse_error("INFO 456 \r\n")
    assert_parse_error("INFO @    \r\n")
    assert_parse_error("INFO \r\n")

    assert_parses(
      binary:   "INFO {\"key\":true}\r\n",
      expected: {:info, %{"key" => true}},
      encoded:  "INFO {\"key\": true}\r\n",
    )

    assert_parses(
      binary:   "INFO { \"key\":true, \"embed\": {\"a\": [\"b\",\"c\", 123] } }\r\n",
      expected: {:info, %{"embed" => %{"a" => ["b", "c", 123]}, "key" => true}},
      encoded:  "INFO {\"embed\": {\"a\": [\"b\", \"c\", 123]}, \"key\": true}\r\n",
    )

    assert_parses(
      binary:   "INFO {}\r\n",
      expected: {:info, %{}},
      encoded:  "INFO {}\r\n",
    )

    assert_parses(
      binary:   "INFO { \"key\":true}\r\n",
      expected: {:info, %{"key" => true}},
      encoded:  "INFO {\"key\": true}\r\n",
    )

    assert_parses(
      binary:   "INFO { \"k1\":true, \"k2\": false}\r\n",
      expected: {:info, %{"k1" => true, "k2" => false}},
      encoded:  "INFO {\"k1\": true, \"k2\": false}\r\n",
    )

    assert_parses(
      binary:   "CONNECT {\"key\":true}\r\n",
      expected: {:connect, %{"key" => true}},
      encoded:  "CONNECT {\"key\": true}\r\n",
    )

    assert_parse_error("INFO []\r\n")
    assert_parse_error("INFO [\r\n")
    assert_parse_error("INFO @\r\n")
    assert_parse_error("INFO [false, true,false,]\r\n")


    {:cont, _howmany, state} = parse("CON")
    {:ok, {:connect, %{}}, "", _} = parse(state, "NECT {}\r\n")

    {:ok, _, "+OK\r\n", _} = parse("PUB S S 1\r\n1\r\n+OK\r\n")
    {:ok, _, "", _} = parse("PUB S S 1\r\n1\r\n")

    assert_parse_error("PUB S S 1\r\n1\rZ+OK\r\n")


    assert_parses(
      binary:   "INFO {\"a\":{\"b\":{\"c\":\"zebra\"}}}\r\n",
      expected: {:info, %{"a" => %{"b" => %{"c" => "zebra"}}}},
      encoded:  "INFO {\"a\": {\"b\": {\"c\": \"zebra\"}}}\r\n",
    )

    assert_parses(
      binary:   "INFO {\"a\": [true,false,null,\"abc\",[1],2.2,[]]}\r\n",
      expected: {:info, %{"a" => [true, false, nil, "abc", [1], 2.2, []]}},
      encoded:  "INFO {\"a\": [true, false, null, \"abc\", [1], 2.2, []]}\r\n",
    )

    assert_parses(
      binary:   "INFO {\"a\":{\"b\":{\"c\":\"zebra\"}}}\r\n",
      expected: {:info, %{"a" => %{"b" => %{"c" => "zebra"}}}},
      encoded:  "INFO {\"a\": {\"b\": {\"c\": \"zebra\"}}}\r\n",
    )

    assert_parses(
      binary:   "CONNECT {\"a\":{\"b\":{\"c\":\"zebra\"}}}\r\n",
      expected: {:connect, %{"a" => %{"b" => %{"c" => "zebra"}}}},
      encoded:  "CONNECT {\"a\": {\"b\": {\"c\": \"zebra\"}}}\r\n",
    )
  end

  test "UNSUB parsing" do
    assert_parses(
      binary:   "UNSUB sid\r\n",
      expected: {:unsub, "sid", nil},
    )
    assert_parses(
      binary:   "UNSUB sid 10\r\n",
      expected: {:unsub, "sid", 10},
    )
    assert_parse_error("UNSUB sid bad\r\n")
  end

  test "SUB parsing" do
    assert_parse_error("SUB bad\r\n")

    assert_parses(
      binary:   "SUB subj sid\r\n",
      expected: {:sub, "subj", nil, "sid"},
    )

    assert_parses(
      binary:   "SUB subj q sid\r\n",
      expected: {:sub, "subj", "q", "sid"},
    )

    assert_parses(
      binary:   "SUB S s\r\n",
      expected: {:sub, "S", nil, "s"},
    )

    assert_parses(
      binary:   "SUB S Q s\r\n",
      expected: {:sub, "S", "Q", "s"},
    )
  end

  test "PUB parsing" do
    assert_parses(
      binary:   "PUB subj 0\r\n\r\n",
      expected: {:pub, "subj", nil, ""},
    )
    assert_parses(
      binary:   "PUB subj 4\r\n1234\r\n",
      expected: {:pub, "subj", nil, "1234"},
    )
    assert_parses(
      binary:   "PUB subj ret 4\r\nnats\r\n",
      expected: {:pub, "subj", "ret", "nats"},
    )
    assert_parses(
      binary:   "PUB subj ret 2\r\nio\r\n",
      expected: {:pub, "subj", "ret", "io"},
    )
    assert_parses(
      binary:   "PUB subj ret 5\r\nnats!\r\n",
      expected: {:pub, "subj", "ret", "nats!"},
    )
    assert_parses(
      binary:   "PUB subj ret 5\r\nnats!\r\n",
      expected: {:pub, "subj", "ret", "nats!"},
    )
    assert_parses(
      binary:   "PUB subj ret 10\r\nhello nats\r\n",
      expected: {:pub, "subj", "ret", "hello nats"},
    )

    assert_parse_error("PUB subj ret -1\r\n")
    assert_parse_error("PUB sub ret zz\r\n")
    assert_parse_error("PUB sub zz\r\n")
    assert_parse_error("PUB zz\r\n")
    assert_parse_error("PUB \r\n")

    assert {:cont, 2, _} = parse("PUB sub ret 0\r\n")
    assert {:cont, 2, _}   = parse("PUB sub 0\r\n")
    assert {:cont, 6, _} = parse("PUB sub ret 4\r\n")
    assert {:cont, 2, _} = parse("PUB sub ret 4\r\nhell")

    assert_parse_error("PUB 0\r\n")
    assert_parse_error("PUB \r\n")

    assert_parses(
      binary:   "PUB S 0\r\n\r\n",
      expected: {:pub, "S", nil, ""},
    )
    assert_parses(
      binary:   "PUB S R 0\r\n\r\n",
      expected: {:pub, "S", "R", ""},
    )
  end

  test "MSG parsing" do
    assert_parses(
      binary:   "MSG subj sid 0\r\n\r\n",
      expected: {:msg, "subj", "sid", nil, ""},
    )
    assert_parses(
      binary:   "MSG subj sid ret 4\r\nnats\r\n",
      expected: {:msg, "subj", "sid", "ret", "nats"},
    )

    assert_parse_error("MSG subj sid ret bad\r\n")
    assert_parse_error("MSG subj sid ret -1\r\n")
    assert_parse_error("MSG subj zz\r\n")
    assert_parse_error("MSG zz\r\n")
    assert_parse_error("MSG \r\n")

    assert_parses(
      binary:   "MSG S s 0\r\n\r\n",
      expected: {:msg, "S", "s", nil, ""},
    )
    assert_parses(
      binary:   "MSG S s R 0\r\n\r\n",
      expected: {:msg, "S", "s", "R", ""},
    )

    assert {:cont, 2, _} = parse("MSG sub ret 0\r\n")

    assert_parse_error("MSG sub 0\r\n")
    assert_parse_error("MSG 0\r\n")
    assert_parse_error("MSG \r\n")

  end

  test "continuation testing to address GH-18" do
    # Thanks @mindreframer !
    # See https://github.com/nats-io/elixir-nats/issues/18

    {:cont, _, state} = parse("CONNECT { \"key\": tru")
    {:cont, _, state} = parse(state, "")
    {:cont, _, state} = parse(state, "e")
    {:cont, _, state} = parse(state, "")
    {:cont, _, state} = parse(state, "      ")
    {:cont, _, state} = parse(state, "}        ")

    {:cont, _, state} = parse(state, "")
    {:cont, _, state} = parse(state, "\r")
    {:ok, {:connect, %{}}, "", _} = parse(state, "\n")

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

    assert_parse_error("SUB SUB SID\r@")
  end
end

