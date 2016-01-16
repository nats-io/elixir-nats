defmodule Nats.Parser do

	defp parse_json(verb, str) do
		case :json_lexer.string(to_char_list(str)) do
			{:ok, tokens, _} ->
				pres = :json_parser.parse(tokens)
				case pres do
					{:ok, json } when is_map(json) -> {:ok, {verb, json}}
					{:ok, json } -> {:error, "NATS: invalid json in #{verb}: not a json_object: #{inspect(json)}"}
					{:error, {_, what, mesg}} -> {:error, "NATS: invalid json in #{verb}: #{inspect(what)} #{mesg}"}
					other -> {:error, "unexpected result #{inspect(other)}"}
				end
			{:eof, _} -> {:error, "NATS: eof for json in verb: #{verb}"}
			{:error, why, mesg} -> {:error, "NATS: invalid json in #{verb}: #{inspect(why)}: #{mesg}"}
			# safe programming ;-)
			other -> {:error, "NATS: unexpected lexer result for json: #{inspect(other)}"}
		end
	end
	
	@endverb "\r\n"
	
	@doc """
  Parse a the NATS protocol from the given `stream`.

  Returns {:ok, message, rest} if a message is parsed from the passed stream, 
  or {:cont, fn } if the message is incomplete.

  ## Examples

  iex>  Nats.Protocol.parse("-ERROR foo\r\n+OK\r")
  {:ok, {:error, "foo"}, "+OK\r" }
  iex>  Nats.Protocol.parse("+OK\r")
  {:cont, ... }
  """
	def parse(thing)

	def parse(thing) do  # when is_list(thing) do
		case :nats_lexer.string(to_char_list(thing)) do
			{:ok, tokens, _} ->
				pres = :nats_parser.parse(tokens)
				case pres do
					{:ok, {:info, str}} -> parse_json(:info, str)
					{:ok, {:connect, str}} -> parse_json(:connect, str)
					{:ok, _} -> pres
					{:error, {_, _, mesg}} -> {:error, "NATS: invalid message: #{mesg}"}
					other -> {:error, "unexpected result #{other}"}
				end
			{:eof, _} -> {:error, "early EOF"}
			{:error, _, rest} -> {:error, "NATS: invalid message: #{rest}"}
			# safe programming ;-)
			other -> {:error, "NATS: unexpected lexer result: #{inspect(other)}"}
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
	def encode({:pub, sub, nil, size}) do
		"PUB #{sub} #{size}\r\n"
	end
	def encode({:pub, sub, reply, size}) do
		"PUB #{sub} #{reply} #{size}\r\n"
	end
	def encode({:sub, sub, nil, sid}) do
		"SUB #{sub} #{sid}\r\n"
	end
	def encode({:sub, sub, queue, sid}) do
		"SUB #{sub} #{queue} #{sid}\r\n"
	end
end
