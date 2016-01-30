# Copyright 2016 Apcera Inc. All rights reserved.
defmodule Nats.Parser do

  defp parse_err(mesg) do
    {:error, "NATS: parsing error: #{mesg}", nil}
  end

  @min_lookahead 4
  defp init_state(rest \\ <<>>, func \\ &verb/2, state \\ nil),
    do: {func, rest, state}
  defp cont(func, state, how_many \\ @min_lookahead, rest \\ <<>>),
    do: {:cont, how_many, init_state(rest, func, state)}
  def parse(string), do: parse(init_state, string)
  def parse(nil, string), do: parse(init_state, string)
  def parse({ func, <<>>, state}, string), do: func.(string, state)
  def parse({ func, buff, state}, string), do: func.(<<buff :: bits,
                                                     string :: bits>>, state)
  defp verb(<<"MSG ", rest :: bits>>, _), do: args(rest, [:msg])
  defp verb(<<"PUB ", rest :: bits>>, _), do: args(rest, [:pub])
  defp verb(<<"SUB ", rest :: bits>>, _), do: args(rest, [:sub])
  defp verb(<<"UNSUB ", rest :: bits>>, _), do: args(rest, [:unsub])
  defp verb(<<"+OK\r\n", rest :: bits>>, _), do: done(rest, :ok)
  defp verb(<<"PING\r\n", rest :: bits>>, _), do: done(rest, :ping)
  defp verb(<<"PONG\r\n", rest :: bits>>, _), do: done(rest, :pong)
  defp verb(<<"CONNECT ", rest :: bits>>, _), do: json(rest, :connect, <<>>)
  defp verb(<<"INFO ", rest :: bits>>, _), do: json(rest, :info, <<>>)
  defp verb(<<"-ERR ", rest :: bits>>, _), do: err(rest, <<>>)

  defp verb(other, state) when byte_size(other) < @min_lookahead,
    # FIXME: jam: fail faster...
    do: cont(&verb/2, state, @min_lookahead, other)
  defp verb(buff, _) do
    read = binary_part(buff, 0, min(16, byte_size(buff)))
    parse_err("invalid protocol bytes: #{inspect(read)}")
  end
  
  defp err(<<>>, acc), do: cont(&err/2, acc)
  defp err(what = <<?\r, _ :: bits>>, acc), do: done(what, [acc, :err])
  defp err(what = <<?\n, _ :: bits>>, acc), do: done(what, [acc, :err])
  defp err(<<char, rest :: bits>>, acc), do: err(rest, <<acc::bits, char>>)
  defp json(<<>>, acc), do: cont(&json/2, acc)
  defp json(what = <<?\r, _ :: bits>>, verb, acc), do: done(what, [acc, verb])
  defp json(what = <<?\n, _ :: bits>>, verb, acc), do: done(what, [acc, verb])
  defp json(<<char, rest :: bits>>, verb, acc),
    do: json(rest, verb, <<acc :: bits, char>>)

  defp args(<<>>, argv), do: cont(&args/2, argv)
  defp args(what = <<?\r, _ :: bits>>, argv), do: done(what, argv)
  defp args(what = <<?\n, _ :: bits>>, argv), do: done(what,  argv)
  defp args(<<?\s, rest :: bits>>, argv), do: args(rest, argv)
  defp args(<<?\t, rest :: bits>>, argv), do: args(rest, argv)
  defp args(<<first, rest :: bits>>, argv),
    do: args_arg(rest, <<first>>, argv)

  # broken out of the above (and below) for continutions
  defp args_arg(buf, so_far, argv) do
    case arg(buf, so_far) do
      {:ok, res, rest} -> args(rest, [res|argv])
      {:cont, sofar} -> cont(&(args_arg(&1, &2, argv)), sofar)
      other -> other
    end
  end
  
  defp arg(<<>>, acc), do: {:cont, acc}
  defp arg(<<?\s, rest :: bits>>, acc), do: {:ok, acc, rest}
  defp arg(<<?\t, rest :: bits>>, acc), do: {:ok, acc, rest}
  defp arg(what = <<?\r, _ :: bits>>, acc), do: {:ok, acc, what}
  defp arg(what = <<?\n, _ :: bits>>, acc), do: {:ok, acc, what}
  defp arg(<<char, rest :: bits>>, acc),
    do: arg(rest, <<acc :: bits, char>>)

  # We're at the end of the body
  defp body(<<"\r\n", rest::bits>>, 0, verb, acc),
    do: {:ok, put_elem(verb, tuple_size(verb) - 1, acc), rest, init_state}
  # We're at the end of the body, but its malformed (missing `\\r\\n`)
  defp body(_rest, 0, verb, _acc),
    do: parse_err("malformed body trailer for: #{inspect(verb)}")
  defp body(<<>>, nleft, verb, acc),
    do: cont(&body_cont/2, {nleft, verb, acc})

  # "We have N more bytes to read"
  defp body(rest, nleft, verb, acc) do
    rest_size = byte_size(rest)
    to_read = min(nleft, rest_size)
#    IO.puts("body -> #{inspect(nleft)} rest=#{inspect(rest)} acc=#{inspect(acc)}")
    <<read :: bytes-size(to_read), remainder :: bits>> = rest
    body(remainder, nleft - to_read, verb, <<acc :: bits, read :: bits>>)
  end
  defp body_cont(buff, {nleft, verb, acc}), do: body(buff, nleft, verb, acc)

  defp done(rest, verb) when is_atom(verb) do
    {:ok, {verb}, rest, nil}
  end
  defp done(buff, argv) when byte_size(buff) < 2, do: cont(&done/2, argv, buff)
  defp done(<<"\r\n", rest :: bits>>, argv) do
    verb = done1(List.to_tuple(Enum.reverse(argv)))
    case verb do
      {:body, want, real_verb} -> body(rest, want, real_verb, <<>>)
      {:error, _, _} -> verb
      other -> {:ok, other, rest, init_state(rest)}
    end
  end
  defp done(<<c1, c2, _ :: bits>>, _),
    do: parse_err("invalid trailer `#{c1}#{c2}`")

  defp parse_json(verb, json_str) do
    case :json_lexer.string(to_char_list(json_str)) do
      {:ok, tokens, _} ->
        pres = :json_parser.parse(tokens)
        case pres do
          {:ok, json } when is_map(json) -> {verb, json}
          {:ok, _ } ->
            parse_err("not a json object in #{verb}: #{inspect(json_str)}")
          {:error, {_, what, mesg}} ->
            parse_err("invalid json in #{verb} #{what}: #{mesg}: #{inspect(json_str)}")
          other ->
            parse_err("unexpected json parser result for #{verb}: #{inspect(other)}: #{inspect(json_str)}")
        end
      {:eof, _} ->
        parse_err("json not complete in #{verb}: #{inspect(json_str)}")
      {:error, {_, why, mesg}} ->
        parse_err("invalid json tokens in #{verb}: #{why}: #{mesg}")
      # safe programming ;-)
      other -> parse_err("unexpected json lexer result for json in #{verb}: #{inspect(other)}: #{inspect(json_str)}")
    end
  end

  
  defp done1(w = {:err, _}), do: w
  defp done1({:info, json}), do: parse_json(:info, json)
  defp done1({:connect, json}), do: parse_json(:connect, json)
  defp done1({:unsub, sid}), do: {:unsub, sid, nil}
  defp done1({:unsub, sid, maxs}) when is_binary(maxs),
    do: done1({:unsub, sid, parse_int(maxs)})
  defp done1({:unsub, sid, maxs}) when maxs == nil or is_integer(maxs),
    do: {:unsub, sid, maxs}

  defp done1(w = {:sub, _sub, _q, _sid}), do: w
  defp done1({:sub, sub,    sid}), do: {:sub, sub, nil, sid}

  defp done1({:pub, sub, size}),
    do: done1({:pub, sub, nil, parse_int(size)})
  defp done1({:pub, sub, ret, size}) when is_binary(size),
    do: done1({:pub, sub, ret, parse_int(size)})
  defp done1(verb = {:pub, _sub, _ret, size}) when is_integer(size),
    do: {:body, size, verb}

  defp done1({:msg, sub,  sid, size}) when is_binary(size),
    do: done1({:msg, sub, sid, nil, parse_int(size)})
  defp done1({:msg, sub, sid, ret, size}) when is_binary(size),
    do: done1({:msg, sub, sid, ret, parse_int(size)})
  defp done1(verb = {:msg, _sub, _sid, _ret, size}) when is_integer(size), 
    do: {:body, size, verb}
  defp done1(verb) do
    why = ""
    # total hack to fix up things so there is ONE error that makes sense
    v = elem(verb, 0)
    if v == :msg || v == :pub do
      case elem(verb, tuple_size(verb) - 1) do
    		{:error, reason} -> why = ": #{reason}"
        size -> size
      end
    end
#    IO.puts("done1 catchall: #{inspect(verb)}: #{why}")
    parse_err("invalid arguments to #{elem(verb,0)}#{why}")
  end
  defp parse_int(what), do: parse_int1(what, Integer.parse(what, 10))
  defp parse_int1(_orig, {result, <<>>}) when result >= 0, do: result
  defp parse_int1(orig, _), do: {:error, "invalid integer: #{orig}"}

 
  def to_json(false) do <<"false">> end
  def to_json(true) do <<"true">> end
  def to_json(nil) do <<"null">> end
  def to_json(n) when is_number(n) do <<"#{n}">> end
  def to_json(str) when is_binary(str) do <<?\">> <> str <> <<?\">> end
  def to_json(map) when is_map(map) do
    <<?\{>> <>
      Enum.join(Enum.map(map, fn({k,v}) -> member_pair(k,v) end), ", ") <>
    <<?}>>
  end
  def to_json(array) when is_list(array) do
    <<?\[>> <>
      Enum.join(Enum.map(array, fn(x) -> to_json(x) end), ", ") <>
    <<?\]>>
  end
  defp member_pair(k,v) when is_binary(k) do
    to_json(k) <> <<": ">> <> to_json(v)
  end
  @endverb "\r\n"
  def encode(mesg) do
    [encode1(mesg), @endverb]
  end
  defp encode1({:ok}) do "+OK" end
  defp encode1({:ping}) do "PING" end
  defp encode1({:pong}) do "PONG" end
  defp encode1({:err, msg}) do ["-ERR ", msg] end
  defp encode1({:info, json}) do ["INFO ", to_json(json)] end
  defp encode1({:connect, json}) do ["CONNECT ", to_json(json)] end
  defp encode1({:msg, sub, sid, nil, what}) do
    ["MSG ", sub, " ", sid, " ", to_string(byte_size(what)), @endverb, what]
  end
  defp encode1({:msg, sub, sid, ret, what}) do
    ["MSG ", sub, " ", sid, " ", ret, " ", to_string(byte_size(what)),
     @endverb, what]
  end
  defp encode1({:pub, sub, nil, what}) do
    ["PUB ", sub, " ", to_string(byte_size(what)), @endverb, what]
  end
  defp encode1({:pub, sub, reply, what}) do
    ["PUB ", sub, " ", reply, " ", to_string(byte_size(what)), @endverb, what]
  end
  defp encode1({:sub, subject, nil, sid}) do
    ["SUB ", subject, " ", sid]
  end
  defp encode1({:sub, subject, queue, sid}) do
    ["SUB ", subject, " ", queue, " ", sid]
  end
  defp encode1({:unsub, sid, nil}), do: ["UNSUB ", sid]
  defp encode1({:unsub, sid, afterReceiving}),
    do: ["UNSUB ", sid, " ", afterReceiving]
end
