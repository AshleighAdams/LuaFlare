# LuaFlare websocket library

`local websocket = require("luaflare.websocket")`

## Example

The following is an example echo server that sends all received messages to all connected clients.

	local echo = websocket.register("/echo", "echo")
	function echo:on_message(client, message)
		self:send(string.format("%s: %s", client.peer, message))
	end


## `websocket.registered`

The websockets that have been registered mapped by path and protocol (`[path][protocol]`).

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


