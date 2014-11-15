# LuaServer util libary

`local util = require("luaserver.util")`

## `number util.time()`

Returns accurate time.

## `util.iterate_dir(string dir, boolean recursive, function callback, ...)`

Iterates a directory, calling `callback` for each path.

## `boolean util.dir_exists(string dir)`

Returns whether or not a directory is valid and exists.

## `table util.dir(string basedir, boolean recursive = false)`

Returns the files in a directory, recursively.

## `boolean util.ensure_path(string path)`

Checks to see if a directory exists.  If it does not, then it is created.

Returns true if it exists, false, if it couldn't be created.
