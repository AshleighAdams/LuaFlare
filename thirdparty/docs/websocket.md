# LuaFlare websocket library

`local websocket = require("luaflare.websocket")`

## `websocket.registered`

## `hosts.upgrades.websocket(request, response)`

The function responsible for upgrading a HTTP request to a websocket connection.

## `wsserver websocket.register(string path, string protocol)`

Registers a websocket.

Valid callbacks:

- `wsserver:on_connect(client)`
- `wsserver:on_message(client, message)`
- `wsserver:on_disconnect(client)`

## `wsserver:send(string message[, client])`

Sends a message to `client` (or all connected if `client` is absent).

## `wsserver:wait()`

Yeild (via scheduler) with an appropriate number of seconds.


