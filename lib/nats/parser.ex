# Copyright 2016 Apcera Inc. All rights reserved.
defmodule Nats.Parser do

  @default_state %{ps: :verb, lexs: [], msg: nil, size: nil, verb: nil}
  def init do
    @default_state
  end

  defp parse_json(state, rest, verb, str) do
    case :json_lexer.string(str) do
      {:ok, tokens, _} ->
        pres = :json_parser.parse(tokens)
        case pres do
          {:ok, json } when is_map(json) -> {:ok, {verb, json}, rest, state}
          {:ok, json } -> parse_err(state, "not a json object in #{verb}", json)
          {:error, {_, what, mesg}} -> parse_err(state, "invalid json in #{verb}", "#{what}: #{mesg}")
          other -> parse_err(state, "unexpected json parser result in #{verb}", other)
        end
      {:eof, _} -> parse_err(state, "json not complete in #{verb}")
      {:error, {_, why, mesg}} -> parse_err(state, "invalid json tokens in #{verb}", [why, mesg])
      # safe programming ;-)
      other -> parse_err(state, "unexpected json lexer result for json in #{verb}", other)
    end
  end

  defp parse_err(state, mesg) do
    {:error, "NATS: parsing error: #{mesg}", %{state | ps: :error}}
  end
  defp parse_err(state, mesg, what) do
    parse_err(state, "#{mesg}: #{inspect(what)}")
  end

  @endverb "\r\n"

  def parse(string) do parse(nil, string) end
  def parse(nil, string) do parse(@default_state, string) end

# @doc """
#  Parse a the NATS protocol from the given `stream`.
#
#  Returns {:ok, message, rest} if a message is parsed from the passed stream, 
#  or {:cont, fn } if the message is incomplete.
#
#  ## Examples
#
#  iex>  Nats.Protocol.parse("-ERROR foo\r\n+OK\r")
#  {:ok, {:error, "foo"}, state}
#  iex>  Nats.Protocol.parse("+OK\r")
#  {:cont, ... }
#  """

  def parse(state = %{ps: :verb, lexs: ls}, thing) do
    res = :nats_lexer.tokens(ls, to_char_list(thing))
    #IO.puts "lex got: #{inspect(nls)}"
    case res do
      {:done, {:ok, tokens, _}, rest} -> parse_verb(state, tokens, to_string(rest))
      {:done, {:eof, _}} -> parse_err(state, "message not complete")
      {:more, nls} -> {:cont, 0, %{state | lexs: nls}}
      other -> parse_err(state, "unexpected lexer return", other)
    end
  end

  defp parse_verb(state, tokens, rest) do  # when is_list(thing) do
    pres = :nats_parser.parse(tokens)
    case pres do
      {:ok, {:info, str}} -> parse_json(state, rest, :info, str)
      {:ok, {:connect, str}} -> parse_json(state, rest, :connect, str)
      {:ok, verb = {:msg, _, _, _, len}} -> 
        parse_body(%{state | ps: :body, size: len + 2, msg: <<>>, verb: verb},
                   rest)
      {:ok, verb = {:pub, _, _, len}} ->
        parse_body(%{state | ps: :body, size: len + 2, msg: <<>>, verb: verb},
                   rest)
      {:ok, verb } -> {:ok, verb, rest, state}
      {:error, {_, _, mesg}} -> parse_err(state, "invalid message", mesg)
      other -> parse_err(state, "unexpected parser return", other)
    end
  end

  # We've parsed the whole body. There may be remaining bytes left in rest
  # so make sure we return them..
  defp parse_body(state = %{ps: :body, size: 0, msg: bd, verb: v}, rest) do
    # replace the last value in the verb with the body.
    tsz = tuple_size(v) - 1
    body_size = elem(v, tsz)
    part = binary_part(bd, body_size, 2)
    #  IO.puts "PART -> #{inspect(part)}"
    if part != "\r\n" do
      parse_err(state, "missing body trailer for #{inspect(v)}", part)
    else
      {:ok, put_elem(v, tsz, binary_part(bd, 0, body_size)),
       rest, @default_state}
    end
  end

  # We've run out of anything to parse and are still looking for a body
  # let the parser's caller know we want more data...
  defp parse_body(state = %{ps: :body, size: sz}, <<>>) do
    {:cont, sz, state}
  end

  # We have more data to read in our body AND there is data to be read, yeah!!!
  # See how much we can slurp up
  defp parse_body(state = %{ps: :body, size: sz, msg: body}, rest) do
    # rest = :erlang.list_to_binary(rest)
    rest_size = byte_size(rest)
    to_read = min(sz, rest_size)
    <<read :: binary-size(to_read), remainder::binary>> = rest
    # IO.puts "reading (#{to_read}): #{inspect(read)}: rest=#{inspect(remainder)}"
    parse_body(%{state | size: sz - to_read, msg: <<body <> read>>}, remainder)
  end
 
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
  def encode(mesg) do
    encode1(mesg) <> @endverb
  end
  defp encode1({:ok}) do <<"+OK">> end
  defp encode1({:ping}) do <<"PING">> end
  defp encode1({:pong}) do <<"PONG">> end
  defp encode1({:err, msg}) do <<"-ERR ">> <> msg end
  defp encode1({:info, json}) do <<"INFO ">> <> to_json(json) end
  defp encode1({:connect, json}) do <<"CONNECT ">> <> to_json(json) end
  defp encode1({:msg, sub, sid, nil, what}) do
    <<"MSG ">> <> sub <>
      <<32>> <> sid <>
      <<32>> <> to_string(byte_size(what)) <> @endverb <> what
  end
  defp encode1({:msg, sub, sid, ret, what}) do
    <<"MSG ">> <> sub <>
      <<32>> <> sid <>
      <<32>> <> ret <>
      <<32>> <> to_string(byte_size(what)) <> @endverb <> what
  end
  defp encode1({:pub, sub, nil, what}) do
    <<"PUB ">> <> sub <> 
      <<32>> <> to_string(byte_size(what)) <> @endverb <> what
  end
  defp encode1({:pub, sub, reply, what}) do
    <<"PUB ">> <> sub <> 
      <<32>> <> reply <>
      <<32>> <> to_string(byte_size(what)) <> @endverb <> what
  end
  defp encode1({:sub, subject, nil, sid}) do
    <<"SUB ">> <> subject <> <<32>> <> sid
  end
  defp encode1({:sub, subject, queue, sid}) do
    <<"SUB ">> <> subject <> <<32>> <> queue <> <<32>> <> sid
  end
end
