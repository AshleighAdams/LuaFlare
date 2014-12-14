# LuaFlare request object

`local request = _G.Request(client)`

The object that represents a request.

## `string request:method()`

Returns the HTTP method used.

## `table request:params()`

Returns a table of query parameters.

## `table request:post_params()`

Returns a table of post parameters (query string like).

## `string request:post_string()`

Returns the raw post data sent with this request.

## `table request:headers()`

Returns a table of headers.

## `string request:url()`

Returns the URL, without any query string.

## `string request:full_url()`

Returns the URL, including the query string.

## `table request:parsed_url()`

Returns all the parts of the URL in a table.

## `tcpclient request:client()`

Returns the underlying tcpclient.

## `number request:start_time()`

Returns when the request created.

## `number request:total_time()`

Returns the seconds passed since the request was created.

## `string request:peer()`

Returns the IP address, following X-Real-IP if a reverse proxy is being used.

## `string request:host()`

Returns the host the request is using.

HTTP/1.2 does not require the Host header to be set, if the first HTTP line specified it.
LuaFlare sets the host for compatibility anyway, but you should still use this.

## `request:parse_cookies()`

Parses the cookies. You shouldn't need to call this, `get_cookie()` and `cookies()` will call this automatically.

## `string request:get_cookie(string name)`

Returns the value of the `name` cookie.

## `table request:cookies()`

Returns a table of cookies.

## `boolean request:is_upgraded()`

Returns true if this request has been upgraded to another type of connection.

## `request:set_upgraded()`

Tell the request that it has been upgraded.

Once this has been called, LuaFlare *forgets* about this connection (does not close it).  As well as avoiding to keep the connection alive (`Connection: keep-alive`).
