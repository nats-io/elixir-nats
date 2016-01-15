% LICENSE, etc,,

Nonterminals
json_object json_members json_pair json_value json_array json_elements.

Terminals
'[' '{' '}' ']' ':' ',' json_true json_false json_null json_number json_string.

Rootsymbol json_value.

json_value -> json_string : list_to_binary(extract('$1')).
json_value -> json_number : extract('$1').
json_value -> json_object : '$1'.
json_value -> json_array : '$1'.
json_value -> json_true : true.
json_value -> json_false : false.
json_value -> json_null : nil.

json_object -> '{' '}' : #{}.
json_object -> '{' json_members '}' : '$2'.

json_members -> json_pair : '$1'.
json_members -> json_members ',' json_pair : maps:merge('$1', '$3').

json_pair -> json_string ':' json_value : #{ list_to_binary(extract('$1')) => '$3' }.

json_array -> '[' ']' : [].
json_array -> '[' json_elements ']' : lists:reverse('$2').

json_elements -> json_value : ['$1'].
json_elements -> json_elements ',' json_value : ['$3' | '$1'].

Erlang code.

extract({_Tok, _Line, Val}) -> Val;
extract({_Tok, Val}) -> Val.
