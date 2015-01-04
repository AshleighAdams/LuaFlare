# Command Line Arguments & Options

## Arguments

### `listen`

Start listening for connections.

### `mount path name`

Mount `path` to `name` inside of `/etc/luaflare/sites/`.
This will change the path's files group to the group by the same name as the user running LuaFlare (by default, `www-data`).

### `unmount name`

Remove a mounted path from `/etc/luaflare/sites/`.

## Options

### `--port=number`

Port to bind to (default `8080`).

### `--threads=number`

Number of threads to create (default `2`).

### `--threads-model=string`

The threading method to use (default `coroutine`).

Valid values for string:

 - coroutine
 - pyrate

### `--host=string`

The host to bind to (default `*`).

### `-l`, `--local`

Bind to only this machine; equivalent to `--host=localhost`.

### `-t`, `--unit-test`

Perform unit tests.

### `-h`, `--help`

Show the help screen.

### `-v`, `--version`

Show the version.

### `--no-reload`

Do not automatically reload Lua scripts when they've changed.

### `--max-etag-size=size`

Specifies the maximum size to generate ETags for.

Supported notation (`K` can also be either: `M`, `G`, `T`, `P`):

 - 1B
 	- 1 byte
 - 1K
 	- 1024 bytes
 - 1KB
 	- 1000 bytes
 - 1KiB
 	- 1024 bytes

### `--reverse-proxy`

Tell LuaFlare that we won't be running stand alone.
The client's peer will be set to `X-Real-IP`.

Only inbound connections from trusted sources are allowed.

### `--trusted-reverse-proxies=string`

Comma delimited list of trusted reverse proxy addresses.

Each element in the list can be one of:

 - IP address
 	- `127.0.0.1`
 - IP address with mask
 	- `192.168.0.0/16`
 - Domain
 	- `myserver.domain.net`

### `--x-accel-redirect=path`

Let LuaFlare use accelerated sending of files with the `X-Accel-Redirect` header.
`path` is what to prepend to the URL so that the reverse proxy redirects to the internal section (by default, this is `/./`).

### `--x-sendfile`

Let LuaFlare use accelerated sending of files with the `X-Sendfile` header.

### `--chunk-size=number`

The number of bytes to send per coroutine yield (default `131072`).

### `--scheduler-tick-rate=number`

The tick rate to resort to if the schedule did not specify one (default is `60`).

### `--max-post-length=number`

Max number of bytes that can be received in a POST request.

### `--systemd`

Enable systemd facilities, such as the heartbeat and notifying systemd on startup completion.

### `--out-pid=path`

Upon startup completion, write our PID to `path`.

### `--keepalive-time`

Maximium number of seconds a connection may be kept alive (default is `2`).

### `--session-tmp-dir=path`

Where to store session (textfiles) files (default: /tmp/luaflare-sessions-XXXXXX).

### `--disable-expects`

Disable type checking for performance.
