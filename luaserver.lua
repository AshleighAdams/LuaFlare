#!/usr/bin/env lua

-- for require() to check modules path
package.path = "./libs/?.lua;" .. package.path
package.cpath = "./libs/?.so;" .. package.cpath

dofile("inc/util.lua")
dofile("inc/syntax_extensions.lua")

local socket = require("socket")
local ssl = require("ssl")
local posix = require("posix")
local configor = require("configor")
local lfs = require("lfs")

local hook = require("luaserver.hook")
local util = require("luaserver.util")
local script = require("luaserver.util.script")

local shorthands = {
	v = "version",
	l = "local",
	t = "unit-test",
	h = "help"
}
script.parse_arguments(arg, shorthands)

dofile("inc/request.lua")
dofile("inc/response.lua")
dofile("inc/savetotable.lua")

	
local port = tonumber(script.options.port) or 8080
local threads = tonumber(script.options.threads) or 2 -- how many threads to create
local host = script.options["local"] and "localhost" or "*"
host = script.options["host"] or host

function handle_client(client)
	local time = util.time()
	while (util.time() - time) < 2 do -- give them 2 seconds
		local request, err = Request(client)
		if not request and err then print(err) return end
		if not request then return end -- probably a keep-alive connection timing out
		
		print(request:peer()  .. " " .. request:method()  .. " " .. request:url())
		
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

local https = false
local params = {
	mode = "server",
--	protocol = "tlsv1",
	protocol = "sslv3",
	key = "keys/key.pem",
	certificate = "keys/certificate.pem",
--	cafile = "keys/request.pem", -- uncomment these lines if you want to verify the client
--	verify = {"peer", "fail_if_no_peer_cert"},
	options = {"all", "no_sslv2"},
	ciphers = "ALL:!ADH:@STRENGTH",
}

function main()
	if script.options["unit-test"] then
		print = static_print
		include("inc/unittests.lua")
		return unit_test()
	elseif script.options.version then
		print = static_print
		print(string.format("LuaServer 2.0 (%s)", _VERSION))
		return
	elseif script.options.help then
		print = static_print
		print([[
--config=path                     Load and save arguments to this file.
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
                                  proxies.
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
]])
		return
	end
	
	
	local thread_mdl = script.options["threads-model"] or "coroutine"
	dofile(string.format("inc/threads_%s.lua", thread_mdl))
	
	dofile("inc/autorun.lua")
	
	assert(main_loop, "`main_loop()` is not defined!")
	main_loop()
end

if script.options["out-pid"] ~= nil then
	local f = io.open(script.options["out-pid"], "w")
	f:write(tostring(script.pid()))
	f:close()
	print("Wrote PID to " .. script.options["out-pid"])
end
main()
