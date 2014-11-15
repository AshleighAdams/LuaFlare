# LuaServer websocket libary

`local websocket = require("luaserver.websocket")`

## `websocket.registered`

## `hosts.upgrades.websocket(request, response)`

The function responsible for upgrading a HTTP request to a websocket connection.

## `wsserver websocket.register(string path, string protocol, table callbacks)`

Registers a websocket.

Valid callbacks:

- `onconnect(client)`
- `onmessage(client, message)`
- `ondisconnect(client)`

## `wsserver:send(string message[, client])`

Sends a message to `client` (or all connected if `client` is absent).

## `wsserver:wait()`

Yeild (via scheduler) with an appropriate number of seconds.


