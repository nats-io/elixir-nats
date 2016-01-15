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
PUB	  = ([Pp][Uu][Bb])
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
% hack state, so we return OK, PING, PONG, ERR, when used in some cases :-(
% rather than ANY_NON_WS (E.g., we aren't looking for beginning of line)
% same issue as recoginizing identifiers and reserved words
% our language needs some work ;-)

{OK}{EOL} : { token, { ok, TokenLine } }.
{PING}{EOL} : { token, { ping, TokenLine } }.
{PONG}{EOL} : { token, { pong, TokenLine } }.
{ERR}{WS}+{ANY}*{EOL} :
 { token, { err, TokenLine,
   list_to_binary(lists:sublist(TokenChars, 6, TokenLen-7)) }}.
{INFO}{WS}+{ANY}*{EOL} :
 { token, {info, TokenLine, lists:sublist(TokenChars, 6, TokenLen-7) }}.
{CONNECT}{WS}+{ANY}*{EOL} :
 { token, {connect, TokenLine, lists:sublist(TokenChars, 9, TokenLen-10) }}.
{MSG}{WS}+ : { token, { msg, TokenLine } }.
{SUB}{WS}+ : { token, { sub, TokenLine } }.
{PUB}{WS}+ : { token, { pub, TokenLine } }.
{UNSUB}{WS}+ : { token, { unsub, TokenLine } }.
{WS} : skip_token.
{EOL} : { token, { eol, TokenLine } }.
{NUM}+ : { token, { num, TokenLine, list_to_integer(TokenChars) } }.
{ANY_NON_WS}+ : { token, { arg, TokenLine, list_to_binary(TokenChars) } }.

Erlang code.
