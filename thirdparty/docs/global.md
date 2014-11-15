# LuaServer global functions

## `expects_types`

A table of type checkers for `expects()`, where key == typename, value = function.

## `valid, reason metatable_compatible(table base, value)`

Returns whether `value` is compatible with the metatable `base`, plus an error reason if it is not.

## `expects(...)`

Checks the caller's arguments against `...`, where each argument in `...` is of either:

- `"any"`: Anything but `nil`.
- `nil`: Argument not tested.
- `string`: Checks `expects_types[str](arg)` or `str == type(arg)`.
- `table`: Checks `tbl == arg` or `metatable_compatible(tbl, arg)`.

## `print_table(table tbl[, done[, depth]])`

Prints a table.

## `number table.count(table t)`

Counts the total number of elements in a table.

## `table.remove_value(table t, any value)`

Removes all values from a table.

## `boolean table.is_empty(table t)`

Returns whether or not the table is empty.

## `boolean table.has_key(table t, any key)

Checks to see if `t` has a key-value pair with the key of `key`.

## `string table.to_string(table t)`

Returns a nice string representation of `t`.

## `boolean string.begins_with(string what, string with)`
### `boolean string.starts_with(string what, string with)`

Checks whether `what` begins with `with`.

## `boolean string.ends_with(string what, string with)`
### `boolean string.stops_with(string what, string with)`

Checks whether `what` ends with `with`.

## `string string.replace(string in, string what, string with)`

Replaces all occurrence of `what` with `with` in `in`.

## `string string.replace_last(string in, string what, string with)`

Replace the last occurrence of `what` with `with` in `in`.

## `string string.path(string)`

TODO: remove this

## `string string.trim(string in)`

Returns `in` without any white space padding.

## `table string.split(string in, string delimiter[, table options])`

Turn `in` into a list separated by `delimiter`.

Valid options:

- `boolean remove_empty`

## `number math.round(number in, number quantum_size = 1)`

Rounds a number to the smallest unit (`quantum_size`).

### Example

    math.round(1.55, 0.25)     == 1.5
    math.round(1.7, 0.25)      == 1.75
    math.round(5.5)            == 6
    math.round(math.pi, 0.001) == 3.142

## `number math.secure_random(number min, number max)`

Returns a secure random number between (inclusive) `min` and `max`.

TODO: currently reads from /dev/urandom, should it read from /dev/random (tho, urandom is seeded by random).

## `output, err_code os.capture(string cmd[, table options])`

Run a command and return the result.

Valid options:

- `boolean stdout`
- `boolean stderr`

## `string name, number version os.platform()`

Returns the lower-case platform name, along with the version.

## `warn(fmt[, ...])`

Dispatch a warning.

## `... include(string path[, ...])`

Includes a file relative the the current file's directory.

Varargs are passed the file as arguments.

Returns the file's returns.
