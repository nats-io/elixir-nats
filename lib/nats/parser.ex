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
  def parse({ func, buff, state}, string), do: func.(<<buff::binary,
                                                     string::binary>>,
                                                     state)
  defp verb(<<"MSG ", rest::binary>>, _), do: args(rest, [:msg])
  defp verb(<<"PUB ", rest::binary>>, _), do: args(rest, [:pub])
  defp verb(<<"SUB ", rest::binary>>, _), do: args(rest, [:sub])
  defp verb(<<"UNSUB ", rest::binary>>, _), do: args(rest, [:unsub])
  defp verb(<<"+OK\r\n", rest::binary>>, _), do: simp_done(:ok, rest)
  defp verb(<<"PING\r\n", rest::binary>>, _), do: simp_done(:ping, rest)
  defp verb(<<"PONG\r\n", rest::binary>>, _), do: simp_done(:pong, rest)
  defp verb(<<"CONNECT ", rest::binary>>, _), do: json(rest, :connect, <<>>)
  defp verb(<<"INFO ", rest::binary>>, _), do: json(rest, :info, <<>>)
  defp verb(<<"-ERR ", rest::binary>>, _), do: err(rest, <<>>)
  @max_match_len 6 # CONNECT and PING\r\n
  defp verb(what, state) when byte_size(what) < @max_match_len,
    do: cont(&verb/2, state, @max_match_len, what)
  defp verb(what, _) do
    read = binary_part(what, 0, min(16, byte_size(what)))
    parse_err("invalid protocol bytes: #{inspect(read)}")
  end
  
  defp err(<<>>, acc), do: cont(&err/2, acc)
  defp err(<<char, rest::binary>>, acc)
    when not char in [?\r, ?\n],
    do: err(rest, <<acc::binary, char>>)
  defp err(what, acc), do: done(what, [acc, :err])
  
  defp json(<<>>, verb, acc), do: cont(&json(&1, verb, &2), acc)
  defp json(<<char, rest::binary>>, verb, acc)
    when not char in [?\r, ?\n],
    do: json(rest, verb, <<acc::binary, char>>)
  defp json(what, verb, acc), do: done(what, [acc, verb])

  defp args(<<>>, argv), do: cont(&args/2, argv)
  defp args(<<?\s, rest::binary>>, argv), do: args(rest, argv)
  defp args(<<?\t, rest::binary>>, argv), do: args(rest, argv)
  defp args(<<char, rest::binary>>, argv)
    when not char in [?\r, ?\n],
    do: arg(rest, <<char>>, argv)
  defp args(what, argv), do: done(what, argv)

  defp arg(<<>>, acc, argv), do: cont(&(arg(&1, acc, &2)), argv)
  defp arg(<<ch, rest::binary>>, acc, argv)
    when ch in[?\s, ?\t], do: args(rest, [acc|argv])
  defp arg(<<char, rest::binary>>, acc, argv)
    when not char in [?\r, ?\n],
    do: arg(rest, <<acc::binary, char>>, argv)
  defp arg(rest, acc, argv), do: args(rest, [acc|argv])
 
  # We're at the end of the body
  defp body(<<"\r\n", rest::binary>>, 0, verb, acc),
    do: {:ok, put_elem(verb, tuple_size(verb) - 1, acc), rest, init_state}
  # We have < 2 bytes in our input, but haven't finished the body
  defp body(buff, nleft, verb, acc)
    when byte_size(buff) < 2,
    do: cont(&body(&1, nleft, verb, &2), acc,
             nleft + (2 - byte_size(buff)), buff)
  # We're at the end of the body, but its malformed (missing `\\r\\n`)
  defp body(_rest, 0, verb, _acc),
    do: parse_err("malformed body trailer for: #{inspect(verb)}")
  # "We have N more bytes to read"
  defp body(rest, nleft, verb, acc) do
    rest_size = byte_size(rest)
    to_read = min(nleft, rest_size)
#    IO.puts("body -> #{inspect(nleft)} rest=#{inspect(rest)} acc=#{inspect(acc)}")
    <<read::bytes-size(to_read), remainder::binary>> = rest
    body(remainder, nleft - to_read, verb, <<acc::binary, read::binary>>)
  end

  defp simp_done(verb, rest), do: {:ok, {verb}, rest, nil}
  defp done(buff, argv) when byte_size(buff) < 2,
    do: cont(&done/2, argv, 2 - byte_size(buff), buff)
  defp done(<<"\r\n", rest::binary>>, argv) do
    verb = done1(List.to_tuple(Enum.reverse(argv)))
    case verb do
      {:body, want, real_verb} -> body(rest, want, real_verb, <<>>)
      {:error, _, _} -> verb
      other -> {:ok, other, rest, init_state}
    end
  end
  defp done(<<c1, c2, _::binary>>, _),
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
    do: ["UNSUB ", sid, " ", to_string(afterReceiving)]
end
