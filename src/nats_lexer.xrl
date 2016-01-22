%% Copyright (c) 2016 Apcera Inc.
%% NATS Protocol Lexer
%%
%% See PROTOCOL.md
%% Don't touch, hacked for now rather than bin generation stuff out of this
%%
%% same grammar.

Definitions.

EOL     = (\r\n)
WS      = [\s\t]
ERR     = (\-[Ee][Rr][Rr])
OK      = (\+[Oo][Kk])
MSG     = ([Mm][Ss][Gg])
SUB     = ([Ss][Uu][Bb])
PUB     = ([Pnp][Uu][Bb])
INFO    = ([Ii][Nn][Ff][Oo])
CONNECT = ([CC][Oo][Nn][Nn][Ee][Cc][Tt])
UNSUB   = ([Uu][Nn][Ss][Uu][Bb])
PING    = ([Pp][Ii][Nn][Gg])
PONG    = ([Pp][Oo][Nn][Gg])
ANY     = [^\r\n]
NUM     = [0-9]
ANY_NON_WS   = [^\r\n\s\t]

Rules.

% Yeah, its a hack for now because this tool is not great and we can't
% hack state, freak out on keywords like MSG/SUB/etc. when used as an ARG...
% and return the wrong thing...
%
% FIXME: jam: don't return keywords when they are used as arguments...
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
 { end_token, {connect, TokenLine, lists:sublist(TokenChars, 9, TokenLen-10) }}.
{MSG}{WS}+ : { token, { msg, TokenLine } }.
{SUB}{WS}+ : { token, { sub, TokenLine } }.
{PUB}{WS}+ : { token, { pub, TokenLine } }.
{UNSUB}{WS}+ : { token, { unsub, TokenLine } }.
{WS} : skip_token.
{NUM}+ : { token, { num, TokenLine, list_to_integer(TokenChars) }}.
{ANY_NON_WS}+ : { token, { arg, TokenLine, list_to_binary(TokenChars) }}.
{EOL} : { end_token, { eol, TokenLine }}.

Erlang code.
