-module(gms1).
-export([start/1, start/2]).

%Since it is the only node in the group it will of course be the leader of the group.
start(Id) ->
    Self = self(),
    {ok, spawn_link(fun()-> init(Id, Self) end)}.

init(Id, Master) ->
    leader(Id, Master, [], [Master]).

%Starting a node that should join an existing group
start(Id, Grp) ->
    Self = self(),
    {ok, spawn_link(fun()-> init(Id, Grp, Self) end)}.

init(Id, Grp, Master) ->
    Self = self(),
    io:format("gms ~w: sending request~n", [Id]),
    Grp ! {join, Master, Self},
    receive
	{view, [Leader|Slaves], Group} ->
	    io:format("gms ~w: Received response~n", [Id]),
	    Master ! {view, Group},
	    slave(Id, Master, Leader, Slaves, Group)
    end.

slave(Id, Master, Leader, Slaves, Group) ->
    receive
	{mcast, Msg} ->
	    %a request from its master to multicast a message, the message is forwarded to the leader.
	    Leader ! {mcast, Msg},
	    slave(Id, Master, Leader, Slaves, Group);
	{join, Wrk, Peer} ->
	    %a request from the master to allow a new nodeto join the group, the message is forwarded to the leader.
	    Leader ! {join, Wrk, Peer},
	    slave(Id, Master, Leader, Slaves, Group);
	{msg, Msg} ->
	    %a multicasted message from the leader. A message Msgis sent to the master.
	    Master ! Msg,
	    slave(Id, Master, Leader, Slaves, Group);
	{view, [Leader|Slaves2], Group2} ->
	    %a multicasted view from the leader. A viewis delivered to the master process.
	    Master ! {view, Group2},
	    slave(Id, Master, Leader, Slaves2, Group2);
	stop -> 
	    ok;
	Error ->
	    io:format("gms ~w: slave msg ~w~n", [Id, Error])
    end.

leader(Id, Master, Slaves, Group) ->
    receive
	{mcast, Msg} ->
	    %message either from its own master or from a peer node
	    bcast(Id, {msg, Msg}, Slaves),
	    Master ! Msg,
	    leader(Id, Master, Slaves, Group);
	{join, Wrk, Peer} ->
	    %a message, from a peer or the master, that is a request from a node to join the group
	    Slaves2 = lists:append(Slaves, [Peer]),
	    Group2 = lists:append(Group, [Wrk]),
	    bcast(Id, {view, [self()|Slaves2], Group2}, Slaves2),
	    Master ! {view, Group2},
	    leader(Id, Master, Slaves2, Group2);
	stop -> 
	    ok;
	Error ->
	    io:format("gms ~w: leader, strange message ~w~n", [Id, Error])
    end.

bcast(_Id, Msg, Nodes) ->
    lists:foreach(fun(Node) -> Node ! Msg end, Nodes).