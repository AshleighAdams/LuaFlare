# LuaFlare session library

`local session = require("luaflare.session")`

Provides session information for a request.

## Hooks

### `session, function save_func "GetSession" string name, string id`

Used in session loading.  Replaces the default save function with `save_func`.

## `session.valid_chars`

When generating a new session ID, use these characters to do it.

## `session session.get(request, response, string name = "session")`

Returns a session object that matches the session name.

If the session does not exist, it is created, along with setting the response cookies for said session.

## *`session:construct(request, response, name, id)`*

Loads the data either by an answered `hook.call("GetSession")` **(TODO)**, or from disk using `table.load`.

## `session:save()`

Saves any changes to the session.

## `string session:id()`

Return the ID of the session.

## `table session:data()`

Return loaded data.  If you make changes, save them with `session:save()`.
