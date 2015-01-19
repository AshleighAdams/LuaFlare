# LuaFlare socket library

LuaFlare itself does not implement sockets directly,
but instead offers an API that backends can implement.

`local socket = require("luaflare.socket")`

The socket API version this document is for is 0.1.

## `socket.backend`

The name of the socket backend.
The CLI option [`--socket-backend`](#options) is used to decide which backend to use.

## `socket.api_version`

The API this backend implements.

This version is taken from the latest LuaFlare version at which these are still compatible.

The API version can be read in "libs/luaflare/socket/none.lua",
or by running `print(require("luaflare.socket.none").api_version)`.

## `bound[, err] socket.bind(number port = 0, string address = "*")`

Bind to an address (start listening for connections).

If `port` is 0, then the operating system will choose it's own port,
usually only temporary (ephemeral).

Address is the address to listen from, "*" will listen to all addresses on all local interfaces.

Returns either the listening object, or `nil` plus an error string.

## `client[, err] socket.connect(string host, number port)`

Connect to a remote host on the specified port.
The host may be a hostname or an IP address.

Returns client or `nil` plus error string.
