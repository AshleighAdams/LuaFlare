# LuaFlare socket API

LuaFlare itself does not implement sockets directly,
but instead offers an API that backends can implement.

`local socket = require("luaflare.socket")`

The socket API version this document targets is 0.3.

## Functions with timeout arguments

If a function has a timeout argument, this means it supports the standard socket timeout behaviour.
This is where if the timeout value (`t`) is less than 0, the function may wait forever;
if `t` is equal to 0, the function inhibits non-blocking behaviour;
and if `t` is above 0, the function may wait either for a maximum of `t` seconds, or until there has been no activity for `t` seconds.

### Future

In future, -1 may mean forever, and -2 to use the client's `:set_timeout()` value,
although this is currently not in this API version.

## Top level functions or values

### `socket.backend`

The name of the socket backend.
The CLI option [`--socket-backend`](#options) is used to decide which backend to use.

### `socket.api_version`

The API this backend implements.

This version is taken from the latest LuaFlare version at which these are still compatible.
The latest API version can be read in "libs/luaflare/socket/none.lua",
or by running `print(require("luaflare.socket.none").api_version)`.

### `listener[, err] socket.listen(string address = "*", number port = 0)`

Bind to an address (start listening for connections).

If `port` is 0, then the operating system will choose it's own port,
usually only temporary (ephemeral).
Address is the address to listen from, "*" will listen to all addresses on all local interfaces.

Returns either the listening object, or `nil` plus an error string.

### `client[, err] socket.connect(string host, number port, number timeout = -1)`

Connect to a remote host on the specified port.
The host may be a hostname or an IP address.

Returns client or `nil` plus error string.

## Listener functions

### `client[, err] listener:accept(number timeout = -1)`

Accept a client from the queue.

### `number listener:port()`

Returns the port number we are/were listening on.

### `string listener:address()`

Returns the address we are/were listening on.

### `listener:close()`

Stop listening.

## Client functions

### `type, backend, version client:type()`

Returns the type of connection, the backend name, and the backend API version.

### `string client:ip()`

Returns the IP address of the client.

### `number client:port()`

Gets the port this client is connecting on.

### `boolean client:connected()`

Returns whether or not this client is connected.

### `data[, err, partial] client:read(string format = "a", number limit = 0, number timeout = -1)`

Read up to `limit` bytes from the stream (infinite if `limit` is 0),
or until the format condition is met; whichever comes first.

The valid formats are either "a", to the end of the stream; and "l", to the end of the line.
The formats may be prefixed with an asterisk (*) to maintain API semantics with Lua 5.2 and below;
this behaviour was deprecated in Lua 5.3 and above.

If data was read, but broke halfway through (such as a timeout or connection failure),
then the partial content that was read will be returned after the error.

### `boolean[, err] client:write(string data, number from = 1, number to = -1, number timeout = -1)`

Write data to the socket; returns `true` if it succeeds,
or `false` plus an error string if it fails.

The values `from` and `to` work just the same as the `string.sub` function.

### `boolean[, err] client:flush(number timeout = -1)`

Flush all written data; returns `true` if it succeeds,
or `false` plus an error string if it fails.

### `client:close()`

Closes the connection.
Does not error if it has already been closed.
