# LuaFlare socket library

LuaFlare itself does not impliment sockets directly,
but instead offers an API that backends can impliment.

`local socket = require("luaflare.socket")`

See [--socket-backend](#socket-backend) for how this is implimented
