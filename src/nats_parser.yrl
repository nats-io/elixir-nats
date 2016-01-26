%%
%% Copyright 2016 Apcera Inc. All rights reserved.
%%

Nonterminals
nats_verb.

Terminals
eol arg num ok err ping pong connect info msg pub sub unsub.

Rootsymbol nats_verb.

nats_verb -> ok : {ok}.
nats_verb -> ping : {ping}.
nats_verb -> pong : {pong}.
nats_verb -> err : {err, extract('$1')}.
nats_verb -> connect : {connect, extract('$1')}.
nats_verb -> info : {info, extract('$1')}.
nats_verb -> msg arg arg arg num eol
  : {msg, extract('$2'), % subject
          extract('$3'), % sid
          extract('$4'), % queue
          extract('$5')  % size
    }.
nats_verb -> msg arg arg num eol
  : {msg, extract('$2'), % subject
          extract('$3'), % sid
                    nil, % queue
          extract('$4')  % size
    }.
nats_verb -> pub arg num eol
  : {pub, extract('$2'),
          nil, % return mbox
          extract('$3')
    }.
nats_verb -> pub arg arg num eol
 : {pub, extract('$2'), extract('$3'), extract('$4')}.
nats_verb -> sub arg arg eol
 : {sub, extract('$2'), nil, extract('$3')}.
nats_verb -> sub arg arg arg eol
 : {sub, extract('$2'), extract('$3'), extract('$4')}.
nats_verb -> unsub arg eol : {unsub, extract('$2'), nil }.
nats_verb -> unsub arg num eol : {unsub, extract('$2'), extract('$3') }.

Erlang code.

extract({_Tok, _Line, Val}) -> Val;
extract({_Tok, Val}) -> Val.
