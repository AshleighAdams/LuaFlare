# LuaFlare httpstatus library

Serves to translate between HTTP status codes and HTTP status messages.

`local httpstatus = require("luaflare.httpstatus")`

## `httpstatus.known_statuses`

A table in of known HTTP statuses, where the key is the status number, and the value is the canonicalized status message.

## `string httpstatus.tostring(number)`

Attempt to convert a status number to a string.

## `number httpstatus.fromstring(string)`

Attempt to find a HTTP status code from a string.
