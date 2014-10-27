# LuaServer escape libary

`local escape = require("luaserver.util.escape")`

Provides methods to escape strings to their safe(er) forms.

## `string escape.pattern(string input)`

Escapes a Lua pattern.

	- `(` -> `%(`
	- `)` -> `%)`
	- `.` -> `%.`
	- `%` -> `%%`
	- `+` -> `%+`
	- `-` -> `%-`
	- `*` -> `%*`
	- `?` -> `%?`
	- `[` -> `%[`
	- `]` -> `%]`
	- `^` -> `%^`
	- `$` -> `%$`

## `string escape.html(string input)`

Escapes a HTML string.

## `string escape.striptags(string input)`

Strips all tags from a string.

## `string escape.sql(string input)`

Returns a safe string to use in SQL queries.

## `string escape.argument(string input)`

Escapes a Unix shell argument.

