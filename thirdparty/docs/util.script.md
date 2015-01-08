# LuaFlare script library

`local script = require("luaflare.util.script")`

## `script.options`

A table of options parsed with `script.parse_options()`.

## `script.arguments`

An array of arguments that were parsed with `script.parse_options()`

## `script.cfg_blacklist`

A list of options that should *not* be saved to disk (i.e. `--help` and `--version`).

## `script.parse_arguments(table args, table shorthands, boolean nosave = false)`

Parse the arguments table into options and arguments.  Shorthands are in the form `["x"] = "big-x"`.

If `nosave` is true, then the configuration file will not be saved.

## `integer script.pid()`

Returns the PID of LuaFlare.

## `string script.instance()`

Returns instance information for the caller.

## `string script.instance_info()`

Returns a complete string used to identify this instance.
