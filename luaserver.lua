#!/usr/bin/env lua

-- for require() to check modules path
package.path = "./libs/?.lua;" .. package.path
package.cpath = "./libs/?.lua;" .. package.cpath

dofile("inc/hooks.lua")
dofile("inc/util.lua")
dofile("inc/htmlwriter.lua")
dofile("inc/requesthooks.lua")
dofile("inc/request.lua")
dofile("inc/response.lua")
dofile("inc/savetotable.lua")
dofile("inc/scheduler.lua")
dofile("inc/websocket.lua")

local socket = require("socket")
local ssl = require("ssl")
local posix = require("posix")
local configor = require("configor")

require("lfs")

local shorthands = {
	v = "version",
	l = "local",
	t = "unit-test",
	h = "help"
}

script.parse_arguments(arg, shorthands)
	
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
			hook.Call("Request", request, response) -- okay, lets invoke whatever is hooked
		
		if request:is_upgraded() then return true end -- don't close the connection!!!
		response:send()
		
		if request:headers().Connection ~= "keep-alive" then
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
--port=number              Port to bind to (default 8080)
--threads=number           Number of threads to create (default 2)
--threads-model=string     Threading mode to use (default 
--host=string              The address to bind to (default *)
-l, --local                Equilivent to --host=localhost
-t, --unit-test            Perfom unit tests and quit
-h, --help                 Show this help
-v, --version              Print out version information and quit.
--no-reload                Don't automatically reload ar_*.lua scripts when
                           they've changed.
--max-etag-size=size       Max size to generate etag hashes for
--x-accel-redirect=path    Use Nginx's X-Accel-Redirect to send files; path is the internal location (the example site uses /internal/)
--x-sendfile               Use mod_sendfile to send files.
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
