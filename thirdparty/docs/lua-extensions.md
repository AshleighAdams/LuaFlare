# LuaFlare Lua extensions

LuaFlare provides some type-checking syntax.  Before loading any code, either by `require()`, `dofile()`, or `include()`, LuaFlare will process the file, and translate the type information to an immediate call to `expects()`.

## Syntax

### type arg `function(type arg)`

Tests `arg` against `"type"`.

### :: `function meta::func()`

Test `self` against `meta`.

### meta& arg `function(meta& arg)`

Tests `arg` against `meta`.

### arg=default `function(msg="hello")`

Set `arg` to `default` if `arg == nil` (placed before `expects()`).

## How `expects()` works

`expects()` will examine the stack, and compare it with the arguments that have been passed to it.

If the type passed type is a string, it will check it against the function `expects_types[typestr](value)` if it exists, else `type(value) == typestr`.  The type string `"any"` will just check against a none-nil value.

If the passed type is nil, it will ignore this argument.

If the passed type is a table, it will ensure the value table contains the same functions (via `metatable_compatible()`).

`expects()` also checks against too many arguments being passed to it.  So this will throw an error: `function(a) expects("string", "number")"`

## Examples, along with translations

### 1 - Standard

`function(string a, number b)`

`function(a, b) expects("string", "number")`

### 2 - `self` checking.

`function meta::func()`

`function meta:func() expects(meta)`

### 3 - Metatable

`function(meta& a)`

`function(a) expects(meta)`

### 4 - Complex

`function meta::dosomething(string arg, meta& other, string message = "hello")`

`function meta:dosomething(arg, other, message) if message == nil then message = "hello" end expects(meta, "string", meta, "string")`
