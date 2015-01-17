# LuaFlare session library

`local session = require("luaflare.session")`

Provides session information for a request.

## Hooks

### `session "GetSession" request, response, string name, string id`

Used to create a session object.

#### `default textfile session`

This is the default handler for this hook; it save to small textfiles in `$configdir/sessions/`.

This hook has a priority of 1.
To override it, make sure that your hook's priority is less than 1.

## `session.valid_chars`

When generating a new session ID, use these characters to do it.

## `session session.get(request, response, string name = "session")`

Returns a session object that matches the session name.

If the session does not exist, it is created, along with setting the response cookies for said session.

## *`session:construct(request, response, name, id)`*

Internal function to construct a textfile session.
Used by the hook "default textfile session" via "GetSession".

## `session:save()`

Saves any changes to the session.

## `string session:id()`

Return the ID of the session.

## `table session:data()`

Return loaded data.  If you make changes, save them with `session:save()`.
