# LuaFlare slug library

Generate human-readable IDs from an input string (usually a title).

`local slug = require("luaflare.util.slug")`

## `script.readable_chars`

A table of all readable chars.

## `script.aliases`

A table of chars and their new values.

## `string script.slug_char(character x, number depth = 0)`

Turns the character `x` into a slug part (excluding spaces).

## `string slug.generate(string input)`

Turns the input string into an ID-safe and human-readble string.
