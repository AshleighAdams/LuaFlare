#!/usr/bin/env lua

dofile("inc/hooks.lua")
dofile("inc/htmlwriter.lua")
dofile("inc/requesthooks.lua")
dofile("inc/util.lua")
dofile("inc/request.lua")
dofile("inc/response.lua")

local socket = require("socket")
local ssl = require("ssl")
require("lfs")

script.parse_arguments(arg)

function handle_client(client)
	local request, err = Request(client)
	if not request then print(err) return end
	
	print(client:getpeername()  .. " " .. request:method()  .. " " .. request:url())
	
	local response = Response(request)
		hook.Call("Request", request, response) -- okay, lets invoke whatever is hooked
	response:send()
end
hook.Add("HandleClient", "default handle client", handle_client)

local function on_error(why, request, response)
	response:set_status(why.type)
	print("error:", why.type, request:url())
end
hook.Add("Error", "log errors", on_error)

local function on_lua_error(err, trace, args)
	print("lua error:", err, trace)
end
hook.Add("LuaError", "log errors", on_lua_error)

local function autorun(dir)
	dir = dir or "lua/"
	for file in lfs.dir("./lua/") do
		if lfs.attributes(dir .. file, "mode") == "file" then
			if file:StartsWith("ar_") and file:EndsWith(".lua") then
				print("autorun: " .. dir .. file)
				dofile(dir .. file)
			end
		elseif file ~= "." and file ~= ".." and lfs.attributes(dir .. file, "mode") == "directory" then
			autorun(dir .. file .. "/")
		end
	end
end
autorun()

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


function socket.bind_reuseport(host, port, backlog)
    if host == "*" then host = "0.0.0.0" end
    local addrinfo, err = socket.dns.getaddrinfo(host);
    if not addrinfo then return nil, err end
    local sock, res
    err = "no info on address"
    for i, alt in ipairs(addrinfo) do
        if alt.family == "inet" then
            sock, err = socket.tcp()
        else
            sock, err = socket.tcp6()
        end
        if not sock then return nil, err end
        sock:setoption("reuseaddr", true)
        sock:setoption("reuseport", true)
        res, err = sock:bind(alt.addr, port)
        if not res then 
            sock:close()
        else 
            res, err = sock:listen(backlog)
            if not res then 
                sock:close()
            else
                return sock
            end
        end 
    end
    return nil, err
end

function main()
	local server, err = socket.bind_reuseport("*", script.options.port or 8080)
	assert(server, err)
	-- so we can spawn many processes, requires luasocket 3 
	--server:setoption("reuseport", true)
	
	while true do
		local client = server:accept()
		--client:settimeout(1000000000000)
		
		if https then
			client, err = ssl.wrap(client, params)
			assert(client, err)
			
			local suc, err = client:dohandshake()
			if not suc then print("ssl failed: ", err) end
		end
		
		hook.Call("HandleClient", client)
		client:close()
	end
end

main() -- then let us run in it