# LuaServer canonicalize_header function

`local canonicalize_header = = require("luaserver.util.canonicalize_header")`

## `header canonicalize_header(string header)`

Returns the conanical form of `header`.
Such as `"host"` to `"Host"`, or `"content-length"` to `"Content-Length"`.


