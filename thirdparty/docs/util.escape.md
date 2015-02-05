# LuaFlare escape library

`local escape = require("luaflare.util.escape")`

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

## `string escape.mysql(string input)`

Returns a safe string to use in MySQL queries.

## `string escape.argument(string input, boolean quotify = true)`

If `quotify`, then the string will be encapsulated in double quotes with a couple special chars escaped;
otherwise, special chars are prefixed with a backslash.

Escapes a Unix shell argument.

# LuaFlare unescape library

`local unescape = require("luaflare.util.unescape")`

Turns strings into their more litteral sense.

## `string unescape.sql(string input)`

Unescape an SQL escaped string.

## `string unescape.url(string input)`

Unescape a URL.
