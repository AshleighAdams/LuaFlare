#!/usr/bin/env lua

-- for require() to check modules path
package.path = "./libs/?.lua;" .. package.path
package.cpath = "./libs/?.lua;" .. package.cpath

dofile("inc/hooks.lua")
dofile("inc/htmlwriter.lua")
dofile("inc/requesthooks.lua")
dofile("inc/util.lua")
dofile("inc/request.lua")
dofile("inc/response.lua")

local socket = require("socket")
local ssl = require("ssl")
local posix = require("posix")
local configor = require("configor")

require("lfs")

script.parse_arguments(arg)
local port = tonumber(script.options.port) or 8080
local threads = tonumber(script.options.threads) or 0 -- how many times we should fork ourselves
local host = script.options["local"] and "localhost" or "*"

function handle_client(client)
	local time = util.time()
	while (util.time() - time) < 2 do -- give them 2 seconds
		local request, err = Request(client)
		if not request and err then print(err) return end
		if not request then return end -- probably a keep-alive connection timing out
		
		print(request:peer()  .. " " .. request:method()  .. " " .. request:url())
		
		local response = Response(request)
			hook.Call("Request", request, response) -- okay, lets invoke whatever is hooked
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
	if script.options["test"] then
		print = static_print
		include("inc/unittests.lua")
		return unit_test()
	end
	
	local server, err = socket.bind(host, port)
	assert(server, err)
	
	hook.Call("ReloadScripts") -- load all of our scritps, before forking anything!
	
	if threads > 0 then
		print("forking children") -- ... lol
		for i = 1, threads do
			if posix.fork() == 0 then break end -- so the forked processes don't fork again
		end
	end
	-- so we can spawn many processes, requires luasocket 3 
	--server:setoption("reuseport", true)
	
	while true do
		local client = server:accept()
		client:settimeout(5) -- 5 seconds until a timeout
		
		if not script.options["no-reload"] then
			hook.Call("ReloadScripts")
		end
		
		if https then
			client, err = ssl.wrap(client, params)
			assert(client, err)
			
			local suc, err = client:dohandshake()
			if not suc then print("ssl failed: ", err) end
		end
		
		handle_client(client)
		client:close()
	end
end

dofile("inc/autorun.lua")
main()
