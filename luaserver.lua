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

configor.loadstring('"this" "is" \n { "a" \n "test" \n }')

if true then return end

script.parse_arguments(arg)
local port = tonumber(script.options.port) or 8080
local threads = tonumber(script.options.threads) or 0 -- how many times we should fork ourselves
local forkonconnect = script.options["fork-on-connect"] or false
local host = script.options["local"] and "localhost" or "*"
local reload_time = script.options["reload-time"] or 5 -- default to every 5 seconds

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

local function on_error(why, request, response)
	response:set_status(why.type)
	print("error:", why.type, request:url())
end
hook.Add("Error", "log errors", on_error)

local function on_lua_error(err, trace, args)
	print("lua error:", err)--, trace)
end
hook.Add("LuaError", "log errors", on_lua_error)

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
	
	if threads > 0 then
		print("forking children") -- ... lol
		for i = 1, threads do
			if posix.fork() == 0 then break end -- so the forked processes don't fork again
		end
	end
	-- so we can spawn many processes, requires luasocket 3 
	--server:setoption("reuseport", true)
	
	hook.Call("ReloadScripts") -- load all of our scritps
	
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
		
		if forkonconnect and posix.fork() == 0 then
			handle_client(client)
			client:close()
			return
		elseif not forkonconnect then
			handle_client(client)
			client:close()
		end
	end
end

local time_table = {}
local includes_files = {}
local dependencies = {}
local function autorun(dir) expects "string"
	for file in lfs.dir(dir) do
		local filename = file
		file = dir .. file
		
		local modified = lfs.attributes(file, "modification")
		
		if modified ~= (time_table[file] or 0) then
			time_table[file] = modified
			
			if lfs.attributes(file, "mode") == "file" then
				if filename:StartsWith("ar_") and filename:EndsWith(".lua") then
					print("autorun: " .. file)
					
					for _, dep in ipairs(dependencies[file] or {}) do -- mark them as not required
						includes_files[dep] = (includes_files[dep] or 1) - 1
						time_table[dep] = lfs.attributes(dep, "modification")
					end
					
					dependencies[file] = include(file)
					
					for _, dep in ipairs(dependencies[file]) do -- remark as required (if an include was removed...)
						includes_files[dep] = (includes_files[dep] or 0) + 1
					end
				elseif includes_files[file] ~= nil and includes_files[file] > 0 then
					print("autorun dependency: " .. file)
					include(file)
				end
			elseif filename ~= "." and filename ~= ".." and lfs.attributes(file, "mode") == "directory" then
				autorun(file .. "/")
			end
			
		end
	end
end

local next_run = 0 -- just limit this to once every ~5 seconds, so under stress
                   -- it wont be slown down
local function reload_scripts()
	if util.time() < next_run then return end
	next_run = util.time() + reload_time
	
	autorun("lua/")
	
	for filename in lfs.dir("sites/") do
		local file = "sites/" .. filename
		
		if filename ~= "." and filename ~= ".." and lfs.attributes(file, "mode") == "directory" then
			if lfs.attributes(file .. "/lua", "mode") == "directory" then
				autorun(file .. "/lua/")
			end
		end
	end
end
hook.Add("ReloadScripts", "reload scripts", reload_scripts)

main()