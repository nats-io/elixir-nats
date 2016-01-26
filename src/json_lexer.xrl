%%
%% Copyright 2016 Apcera Inc. All rights reserved.
%%
%% JSON lexer
%%
%% See http://www.json.org/

Definitions.

JSON_WS   = [\s\t\r\n]
HEX       = [A-Fa-f0-9]
HEXE      = {HEX}{HEX}{HEX}{HEX}
JSON_CHAR = ([\x20-\x21\x23-\x5b\x5d-\x{10FFFF}]|(\\([\"\\/bfnrt]|u{HEXE})))
JSON_INT  = (-?(0|([1-9]([0-9]*))))
JSON_NUM  = ({JSON_INT}((\.[0-9]+)?)(([eE](\-|\+)?[0-9]+)?))
TERMS     = ([\{\}\[\],\;\:])

Rules.

true : { token, { json_true, TokenLine } }.
false : { token, { json_false, TokenLine } }.
null : { token, { json_null, TokenLine } }.
{TERMS} : { token, { list_to_atom (TokenChars), TokenLine } }.
"{JSON_CHAR}*" : { token, { json_string, TokenLine,
                   lists:sublist(TokenChars, 2, TokenLen - 2) } }.
{JSON_INT} : { token, { json_number, TokenLine,
              list_to_integer(TokenChars) } }.
{JSON_NUM} : { token, { json_number, TokenLine,
               list_to_float(TokenChars) } }.
{JSON_WS} : skip_token.

Erlang code.
