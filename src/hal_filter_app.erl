-module(hal_filter_app).
-export([handle/2, base_capabilities/0]).
-define(URL, "https://api.archives-ouvertes.fr/search/?fq=submitType_s:file&fl=title_s,uri_s,fileMain_s&wt=json&rows=15&q=").

base_capabilities() ->
    em_filter:base_capabilities() ++
    [<<"paper">>, <<"papers">>, <<"research">>, <<"science">>, <<"academic">>,
     <<"thesis">>, <<"these">>, <<"article">>, <<"pdf">>, <<"hal">>, <<"document">>,
     <<"publication">>, <<"recherche">>, <<"scientifique">>, <<"memoire">>, <<"open">>].

handle(Body, Memory) when is_binary(Body) -> {gen(extract_value(Body)), Memory};
handle(_Body, Memory) -> {[], Memory}.

gen("") -> [];
gen(Q) ->
    Url = ?URL ++ uri_string:quote(Q),
    case fetch_json(Url) of
        {ok, #{<<"response">> := #{<<"docs">> := Ds}}} when is_list(Ds) ->
            lists:filtermap(fun emb/1, Ds);
        _ -> []
    end.

emb(#{<<"fileMain_s">> := Pdf} = D) when is_binary(Pdf), byte_size(Pdf) > 0 ->
    Title = case maps:get(<<"title_s">>, D, []) of
                [T | _] when is_binary(T) -> T;
                T when is_binary(T)       -> T;
                _                         -> <<"HAL document">>
            end,
    Page = safe(maps:get(<<"uri_s">>, D, <<>>)),
    {true, #{<<"properties">> => #{
        <<"url">> => Pdf, <<"title">> => Title, <<"resume">> => Page,
        <<"doc_type">> => <<"pdf">>, <<"source">> => <<"HAL">>}}};
emb(_) -> false.

%%==================== helpers ====================
extract_value(Body) ->
    try json:decode(Body) of
        Map when is_map(Map) ->
            binary_to_list(maps:get(<<"value">>, Map, maps:get(<<"query">>, Map, <<"">>)));
        _ -> binary_to_list(Body)
    catch _:_ -> binary_to_list(Body) end.

fetch_json(Url) ->
    _ = application:ensure_all_started(inets),
    Headers = [{"User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0"}],
    case httpc:request(get, {Url, Headers},
                       [{timeout, 15000}, {ssl, [{verify, verify_none}]}],
                       [{body_format, binary}]) of
        {ok, {{_, 200, _}, _, B}} ->
            case catch json:decode(B) of M when is_map(M) -> {ok, M}; _ -> error end;
        _ -> error
    end.

txt(IoList) ->
    case unicode:characters_to_binary(IoList) of Bin when is_binary(Bin) -> Bin; _ -> <<>> end.

safe(B) when is_binary(B) -> B;
safe(L) when is_list(L) -> case unicode:characters_to_binary(L) of X when is_binary(X) -> X; _ -> <<>> end;
safe(_) -> <<>>.
