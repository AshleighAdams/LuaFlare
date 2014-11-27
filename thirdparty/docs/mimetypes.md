# LuaFlare mimetypes library

`local mimetypes = require("luaflare.mimetypes")`

Translate file extensions to mime types.  Has basic types inbuilt, and loads the rest from `/etc/mime.types`

### `mimetypes.types`

The loaded data.  Key is file extension, value is mimetype.

### `mimetypes.guess(string path)`

Returns the mimetype associated with `path`, or nil.
