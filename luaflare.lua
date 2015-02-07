#!/usr/bin/lua

local function usage()
	io.stdout:write([[
usage:
    luaflare listen [OPTIONS]...
    luaflare mount PATH NAME
    luaflare unmount NAME
    luaflare unit-test
    luaflare [OPTIONS]...

--port=number                     Port to bind to (default 8080).
--threads=number                  Number of threads to create (default 2).
--threads-model=string            Threading mode to use (default coroutine).
--host=string                     The address to bind to (default *).
-l, --local                       Equivalent to: --host=localhost
-t, --unit-test                   Perform unit tests and quit.
-h, --help                        Show this help.
-v, --version                     Print out version information and quit.
--no-reload                       Don't automatically reload ar_*.lua scripts
                                  when they've changed.
--max-etag-size=size              Max size to generate etag hashes for. (default
                                  64MiB).
--reverse-proxy                   Require X-Real-IP and X-Forward-For.
--trusted-reverse-proxies=string  Comma delimitered list of trusted reverse
                                  proxies. Mask notation is supported.
--x-accel-redirect=path           Use Nginx's X-Accel-Redirect to send static
                                  content; path is the internal location (the 
                                  example site uses /./)
--x-sendfile                      Use mod_xsendfile to send static content.
--chunk-size                      Number of bytes to send per chunk (default
                                  128KiB (1024*128).  Lower values means less
                                  susceptible to fuzzing attacks, but lower
                                  transfer speeds.
--display-all-vars                On a Lua error, show all variables, not just
                                  related.
--scheduler-tick-rate=number      The fallback tickrate (Hz) for a schedule that
                                  yields nil. (default 60).
--max-post-length=number          The maximum length of the post data.
--systemd                         Notify systemd upon startup, and try to
                                  heartbeat.
--out-pid=file                    Write our PID to this file post load.
--keepalive-time=number           Maximum number of seconds a connection can
                                  be kept alive (default 2).
--session-tmp-dir=path            Where to store session (textfiles)
                                  files (default: /tmp/luaflare-sessions-XXXXXX)
--disable-expects                 Disable type checking for performance.
--socket-backend=string           The backend to use for sockets (default is
                                  "luasocket").
--escape-html-warn-buckets=number Warn when this many buckets exist for escaping
                                  HTML strings (default 1024).
]])
end
-- so we can exit ASAP, for bash completion speedy-ness
if arg[1] == "--help" then return usage() end

-- try to bootstrap
do -- for require() to check modules path
	local tp, tcp = package.path, package.cpath
	
	local path = os.getenv("LUAFLARE_LIB_DIR") or arg[0]:match("(.+)/") or "."
	
	package.path = path .. "/libs/?.lua;" .. tp
	package.cpath = path .. "/libs/?.so;" .. tcp
	
	local bootstrap, err = loadfile(path.."/bootstrap/bootstrap.lua")
	if not bootstrap then
		io.stderr:write("failed to bootstrap: "..tostring(err).."\n")
		os.exit(1)
	end
	bootstrap{path=path}
end

local luaflare = require("luaflare")

local socket = require("socket")
local posix = require("posix")
local configor = require("configor")
local lfs = require("lfs")

local hook = require("luaflare.hook")
local util = require("luaflare.util")
local script = require("luaflare.util.script")
local escape = require("luaflare.util.escape")

local shorthands = {
	v = "version",
	l = "local",
	t = "unit-test",
	h = "help"
}
script.parse_arguments(arg, shorthands)

include(luaflare.lib_path.."/inc/request.lua")
include(luaflare.lib_path.."/inc/response.lua")

do
	local main = require("luaflare.main")
	local action = script.arguments[1]
	
	if script.options["unit-test"] then
		action = "unit-test"
	elseif script.options.version then
		return print(string.format("%s (%s)", luaflare._VERSION, _VERSION))
	elseif script.options.help then
		return usage()
	elseif not action then
		return
	end
	
	local escp_action = action:gsub("%-", "_")
	
	if not main.actions[escp_action] then
		io.stderr:write(string.format("error: unknown action: %s\n", action))
		os.exit(1)
	end
	
	local args = {}
	for i = 2, #script.arguments do
		table.insert(args, script.arguments[i])
	end
	
	main.actions[escp_action](table.unpack(args))
end
