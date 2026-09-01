-module(hal_filter_boot).
-behaviour(application).
-behaviour(supervisor).
-export([start/2, stop/1, init/1]).

start(_Type, _Args) ->
    {ok, Pid} = supervisor:start_link({local, hal_filter_boot_sup}, ?MODULE, []),
    _ = application:ensure_all_started(em_filter),
    _ = em_filter:start_agent(hal_filter, hal_filter_app,
          #{pop_port => 9572, query_port => 9573,
            capabilities => hal_filter_app:base_capabilities(),
            pop_peers => [{"localhost", 9100}], pop_role => leaf}),
    {ok, Pid}.

stop(_State) -> ok.

init([]) ->
    {ok, {#{strategy => one_for_one, intensity => 1, period => 5}, []}}.
