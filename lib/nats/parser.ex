defmodule Nats.Parser do

	defp parse_json(state, verb, str) do
		case :json_lexer.string(to_char_list(str)) do
			{:ok, tokens, _} ->
				pres = :json_parser.parse(tokens)
				case pres do
					{:ok, json } when is_map(json) -> {:ok, {verb, json}, state}
					{:ok, json } -> parse_err(state, "not a json object in #{verb}", json)
					{:error, {_, what, mesg}} -> parse_err(state, "invalid json in #{verb}", "#{what}: #{mesg}")
					other -> parse_err(state, "unexpected json parser result in #{verb}", inspect(other))
				end
			{:eof, _} -> parse_err(state, "json not complete in #{verb}")
			{:error, {_, why, mesg}} -> parse_err(state, "invalid json tokens in #{verb}", [why, mesg])
			# safe programming ;-)
			other -> parse_err(state, "unexpected json lexer result for json in #{verb}", other)
		end
	end

	def parse_err(_state, mesg) do
		{:error, "NATS: parsing error: #{mesg}"}
	end
	def parse_err(state, mesg, what) do
		parse_err(state, "#{mesg}: #{what}")
	end
	@endverb "\r\n"
	
	@doc """
  Parse a the NATS protocol from the given `stream`.

  Returns {:ok, message, rest} if a message is parsed from the passed stream, 
  or {:cont, fn } if the message is incomplete.

  ## Examples

  iex>  Nats.Protocol.parse("-ERROR foo\r\n+OK\r")
  {:ok, {:error, "foo"}, state}
  iex>  Nats.Protocol.parse("+OK\r")
  {:cont, ... }
  """
	def parse(thing) do
		parse([], thing)
	end

	def parse(state, thing) do
		res = :nats_lexer.tokens(state, to_char_list(thing))
#		IO.puts "lex got: #{inspect(res)}"
		case res do
			{:done, {:ok, tokens, _}, rest} -> parse_verb(rest, tokens)
			{:done, {:eof, _}} -> parse_err(state, "message not complete")
			{:more, state} -> {:more, state}
			other -> parse_err(state, "unexpected lexer return", other)
		end
	end

	def parse_verb(state, thing) do  # when is_list(thing) do
		pres = :nats_parser.parse(thing)
		case pres do
			{:ok, {:info, str}} -> parse_json(state, :info, str)
			{:ok, {:connect, str}} -> parse_json(state, :connect, str)
			{:ok, verb } -> {:ok, verb, state}
			{:error, {_, _, mesg}} -> parse_err(state, "invalid message", mesg)
			other -> parse_err(state, "unexpected parser return", other)
		end
	end

	def to_json(false) do "false" end
	def to_json(true) do "true" end
	def to_json(nil) do "null" end
	def to_json(str) when is_binary(str) do "\"#{str}\"" end
	def to_json(map) when is_map(map) do
		pairs = Enum.join(Enum.map(map, fn({k,v}) -> member_pair(k,v) end), ", ")
		"{#{pairs}}"
	end
	def to_json(array) when is_list(array) do
		elements = Enum.join(Enum.map(array, fn(x) -> to_json(x) end), ", ")
		"[#{elements}]"
	end
	defp member_pair(k,v) when is_binary(k) do
		"#{to_json(k)}: #{to_json(v)}"
	end

	
  def encode({:ok, rest}) do encode(rest) end
	def encode({:ok}) do "+OK\r\n" end
	def encode({:ping}) do "PING\r\n" end
	def encode({:pong}) do "PONG\r\n" end
	def encode({:err, msg}) do "-ERR #{msg}\r\n" end
	def encode({:info, json}) do "INFO #{to_json(json)}\r\n" end
	def encode({:connect, json}) do "CONNECT #{to_json(json)}\r\n" end
	def encode({:msg, sub, sid, nil, size}) do
		"MSG #{sub} #{sid} #{size}\r\n"
	end
	def encode({:msg, sub, sid, queue, size}) do
		"MSG #{sub} #{sid} #{queue} #{size}\r\n"
	end
	def encode({:pub, sub, nil, what}) do
		"PUB #{sub} #{byte_size(what)}\r\n#{what}\r\n"
	end
	def encode({:pub, sub, reply, what}) do
		"PUB #{sub} #{reply} #{byte_size(what)}\r\n#{what}\r\n" 
	end
	def encode({:sub, sub, nil, sid}) do
		"SUB #{sub} #{sid}\r\n"
	end
	def encode({:sub, sub, queue, sid}) do
		"SUB #{sub} #{queue} #{sid}\r\n"
	end
end
