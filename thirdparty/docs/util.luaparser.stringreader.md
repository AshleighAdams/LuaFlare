# LuaFlare stringreader object

`local stringreader = require("luaflare.util.luaparser.stringreader")`

A helper libary used by `luaparser`.

## `reader stringreader.new(string data)`

Constructs a reader object.

## `string reader:read(number count = 1)`

Reads `count` bytes from the stream, and increases the position.

## `string reader:peek(number count = 1)`

Reads `count` bytes from the stream. Does not increase the position.

## `string reader:peekat(number offset, number count = 1)`

Peeks `count` bytes at position `offset`.

## `string reader:peekmatch(string pattern)`

Returns the match at the current position.

## `string reader:readmatch(string pattern)`

Returns the match at the current position, along with increasing the position.

## `boolean reader:eof()`

Returns whether the end has been reached.
