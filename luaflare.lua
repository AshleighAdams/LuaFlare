#!/usr/bin/lua

local function usage()
	print([[
usage:
    luaflare listen [OPTIONS]...
    luaflare mount PATH NAME
    luaflare unmount NAME
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
	
local port = tonumber(script.options.port) or 8080
local threads = tonumber(script.options.threads) or 2 -- how many threads to create
local host = script.options["local"] and "localhost" or "*"
local keepalive_time = tonumber(script.options["keepalive-time"]) or 65
host = script.options["host"] or host

function handle_client(client)
	local time = util.time()
	while (util.time() - time) <= keepalive_time do -- give them until the specified time limit
		local request, err = Request(client)
		if not request and err then warn(err) return end
		if not request then return end -- probably a keep-alive connection timing out
		
		print(request:peer()  .. " " .. request:method()  .. " " .. request:path())
		
		local response = Response(request)
			hook.safe_call("Request", request, response) -- okay, lets invoke whatever is hooked
		
		if request:is_upgraded() then return true end -- don't close the connection!!!
		response:send()
		
		if not request:headers().Connection 
		or not request:headers().Connection:lower():match("keep%-alive") 
		then -- break if the connection is not being kept alive
			break
		end
	end
end

function main()
	if script.options["unit-test"] then
		include(luaflare.lib_path .. "/inc/unittests.lua")
		return unit_test()
	elseif script.options.version then
		return print(string.format("%s (%s)", luaflare._VERSION, _VERSION))
	elseif script.options.help then
		return usage()
	end
	
	if script.arguments[1] == "templator" then
		hook.call("Loaded")
		
		local templator = require("luaflare.templator")
		local profiler = require("luaflare.profiler")
		local html = [[
<html>
	<head>
		<title>$(title)</title>
	</head>
	<body>
		<h1>$(title)</h1>
		<p>
			$(body)
		</p>
	</body>
</html>
]]
		local gen = templator.generate(html)
		
		profiler.start()
		local final = gen {
			title = "Hello",
			body = "Hello world!\n<script>alert('hi');</script>"
		}
		profiler.stop()
		
		print(table.to_string(gen))
		print(final)
		
		return
	end
	
	
	if script.arguments[1] == "socket" then
		local socket = require("luaflare.socket.posix")
		local util = require("luaflare.util")
		
		do
			local sock = assert(socket.connect("kateadams.eu", 80))
			sock:write(table.concat({
				"GET / HTTP/1.1",
				"Host: kateadams.eu",
				"Connection: close",
				"", ""
			}, "\n"))
			
			local length
			local status = sock:read("l", 512)
			while true do
				local line = sock:read("l", 512)
				print(line)
				if line == "" then break end
				local header, contents = line:match("([^:]+):%s*(.+)")
				if header and header:lower() == "content-length" then
					length = tonumber(contents)
				end
			end
			
			print(status)
			print("length: ", length)
			local content = sock:read("a", length)
			print("read:", content:len())
			print()
		end
		
		do
			local listener = assert(socket.listen("*", 8080))
			while true do
				local sock = assert(listener:accept())
				local st = util.time()
				
				print(sock)
				
				local header = sock:read("l")
				
				local method, url, version = header:match("([^ ]+) ([^ ]+) HTTP/([^ ]+)")
				local headers = {}
				
				while true do
					local line = sock:read("l")
					if line == "" then
						break
					else
						table.insert(headers, line)
					end
				end
				
				print(method .." ".. url)
				
				local response = string.format("method: %s<br>url: %s<br>version: %s<br>generated in: ", method, url, version)
				response = response .. ((util.time() - st) * 1000) .. " ms"
				local response_headers = {
					"HTTP/1.1 200 Okay",
					"Connection: close",
					"Content-Type: text/html",
					"Content-Length: " .. (#response),
					"",
					response
				}
				
				sock:write(table.concat(response_headers, "\n"))
				sock:close()
			end
		end
		
		return
	end
	
	if script.arguments[1] == "listen" then
		local thread_mdl = script.options["threads-model"] or "coroutine"
		dofile(string.format("%s/inc/threads_%s.lua", luaflare.lib_path, thread_mdl))
	
		dofile(luaflare.lib_path .. "/inc/autorun.lua")
		assert(main_loop, "`main_loop()` is not defined!")
	
		main_loop()
	elseif script.arguments[1] == "mount" then
		local dir = script.arguments[2]
		local name = script.arguments[3]
		if not dir then print("error: expected PATH") return usage() end
		if not name then print("error: expected NAME") return usage() end
		
		name = luaflare.config_path .. "/sites/" .. name
		
		local user = posix.getlogin()
		if posix.getgroup(user) == nil then
			print("error: failed to set group of mounted directory: user " .. user .. " does not have a group by the same name")
			return os.exit(1)
		end
		
		print(string.format("mounting %s at %s", dir, name))
		print("creating link")
		if os.execute(string.format("ln -s \"`pwd`/%s\" \"%s\"", escape.argument(dir), escape.argument(name))) ~= 0 then
			return os.exit(1)
		end
		print("setting group; ensure your user is in the group " .. user .. " via:")
		print("sudo usermod -a -G \"" .. user .. "\" \"`whoami`\"")
		if os.execute(string.format("sudo chgrp -R \"%s\" \"%s\"", escape.argument(user), escape.argument(name))) ~= 0 then
			return os.exit(1)
		end
		
		print("okay")
		return
	elseif script.arguments[1] == "unmount" then
		local name = script.arguments[2]
		if not name then print("error: expected NAME") return usage() end
		
		name = luaflare.config_path .. "/sites/" .. name
		
		print(string.format("unmounting %s", name))
		if os.execute(string.format("rm -r \"%s\"", escape.argument(name))) ~= 0 then
			return os.exit(1)
		end
		
		print("okay")
		return
	elseif script.arguments[1] then
		print("unknown action " .. script.arguments[1])
	end
end



main()
