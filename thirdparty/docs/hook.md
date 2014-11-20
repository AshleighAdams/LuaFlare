# LuaFlare hook libary

`local hook = require("luaflare.hook")`

## *`hook.invalidate(any name)`*

Rebuilds the `callorder` table.  Called automatically by `hook.add()` and `hook.remove()`.

- `name`: The hook name.

## `hook.add(any name, any id, function callback[, number priority])`

Adds a hook.  Returning a none-nil value will prevent callbacks yet-to-be-called from being invoked.

- `name`: The hook name.
- `id`: A unique ID for this hook.
- `callback`: The function to invoke upon the hook being called.
- `priority`: Hooks with a lower priority are called first (default `0`).

## `hook.remove(any name, any id)`

Removes a hook.

- `name`: The hook `id` belongs to.
- `id`: The ID of the hook.

## `... hook.call(any name, ...)`

Invokes all functions subscribed to this hook.

- `name`: The hook name.
- `...`: The arguments to the hook.
- returns: nil, unless a hook returned a none-nil value (meaning not all hooks were called).

## `... hook.safe_call(any name, ...)`

- Same as `hook.call()`, except any errors are caught, and attempts to show the Lua error page.


