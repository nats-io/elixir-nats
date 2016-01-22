%% Copyright (c) 2016 Apcera Inc.
%% NATS Protocol Lexer
%%
%% See ../PROTOCOL.Md
%% Don't touch, hacked for now rather than bin generation stuff out of this same
%% grammar.

Definitions.

EOL	  = (\r\n)
WS	  = [\s\t]
ERR	  = (\-[Ee][Rr][Rr])
OK	  = (\+[Oo][Kk])
MSG	  = ([Mm][Ss][Gg])
SUB	  = ([Ss][Uu][Bb])
PUB	  = ([Pnp][Uu][Bb])
INFO  = ([Ii][Nn][Ff][Oo])
CONNECT  = ([CC][Oo][Nn][Nn][Ee][Cc][Tt])
UNSUB	  = ([Uu][Nn][Ss][Uu][Bb])
PING	  = ([Pp][Ii][Nn][Gg])
PONG	  = ([Pp][Oo][Nn][Gg])
ANY	  = [^\r\n]
ANY_NON_WS	  = [^\r\n\s\t]
NUM  = [0-9]

Rules.

% Yeah, its a hack for now because this tool is not great and we can't
% hack state, so we push back EOL and match verbs on that so we don't return
% keywords like MSG/SUB/etc. when used as an ARG...
%
% As stated in the header, for now this is time to market based vs.
% performance ;-)
%

{OK}{EOL} : { end_token, { ok, TokenLine }}.
{PING}{EOL} : { end_token, { ping, TokenLine }}.
{PONG}{EOL} : { end_token, { pong, TokenLine }}.
{ERR}{WS}+{ANY}*{EOL} :
 { end_token, { err, TokenLine,
   list_to_binary(lists:sublist(TokenChars, 6, TokenLen-7)) }}.
{INFO}{WS}+{ANY}*{EOL} :
 { end_token, {info, TokenLine, lists:sublist(TokenChars, 6, TokenLen-7) }}.
{CONNECT}{WS}+{ANY}*{EOL} :
 { end_token, {connect, TokenLine, lists:sublist(TokenChars, 9,
   	       TokenLen-10) }}.
{MSG}{WS}+ : { token, { msg, TokenLine } }.
{SUB}{WS}+ : { token, { sub, TokenLine } }.
{PUB}{WS}+ : { token, { pub, TokenLine } }.
{UNSUB}{WS}+ : { token, { unsub, TokenLine } }.
{WS} : skip_token.
{NUM}+ : { token, { num, TokenLine, list_to_integer(TokenChars) }}.
{ANY_NON_WS}+ : { token, { arg, TokenLine, list_to_binary(TokenChars) }}.
{EOL} : { end_token, { eol, TokenLine }}.

Erlang code.
