local main = {}
main.actions = {}

local luaflare = require("luaflare")
local hook = require("luaflare.hook")
local hosts = require("luaflare.hosts")
local util = require("luaflare.util")
local script = require("luaflare.util.script")

local posix = require("posix")

function main.actions.listen()
	local function signal_shutdown()
		print("Unloading...")
		hook.call("Unload")
		os.exit(0)
	end
	posix.signal(posix.SIGHUP, signal_shutdown)
	posix.signal(posix.SIGINT, signal_shutdown)
	
	include(luaflare.lib_path .. "/inc/autorun.lua")
	
	hook.call("ReloadScripts")
	
	local host = script.options["local"] and "localhost" or "*"
	local model = script.options["threads-model"] or "coroutine"
	
	local listen_options = {
		port = tonumber(script.options.port) or 8080,
		threads = tonumber(script.options.threads) or 2, -- how many threads to create
		keepalive_time = tonumber(script.options["keepalive-time"]) or 65,
		host = script.options["host"] or host,
		no_reload = script.options["no-reload"],
		reload_time = tonumber(script.options["reload-time"]) or 5,
		max_wait = 0.5
	}
	
	local model = require("luaflare.main."..model)
	model.listen(listen_options)
end

function main.actions.mount(dir, name)
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
	
	print("done")
end

function main.actions.unmount(string name)
	if not name then print("error: expected NAME") return usage() end
	
	name = luaflare.config_path .. "/sites/" .. name
	
	print(string.format("unmounting %s", name))
	if os.execute(string.format("rm -r \"%s\"", escape.argument(name))) ~= 0 then
		return os.exit(1)
	end
	
	print("done")
end

function main.actions.unit_test()
	include(luaflare.lib_path .. "/inc/unittests.lua")
	unit_test()
end

local keepalive_time = tonumber(script.options["keepalive-time"]) or 65
function main.handle_socket(sock)
	local time = util.time()
	while (util.time() - time) <= keepalive_time do -- give them until the specified time limit
		local request, err = Request(sock)
		
		if not request then
			if err then
				warn(err)
			end
			sock:close()
			return
		end
		
		local response = Response(request)
		
		hook.safe_call("Request", request, response) -- okay, lets invoke whatever is hooked
		
		if not request:owns_socket() then
			-- we no longer own the socket; the connection is likley to not be
			-- HTTP anymore too, so let's "forget" about it (not close it).
			
			print(string.format("%s %s %s", request:peer(), request:method(), request:path(), "disowned"))
			return
		end
		
		print(string.format("%s %s %s: %d", request:peer(), request:method(), request:path(), response:status()))
		response:send()
		
		local connection = request:headers().Connection 
		if not connection or connection:lower():match("close") then
			-- they havn't asked us to keep the connection alive, or asked us to close it
			sock:close()
			return
		end
	end
end


-- testing stuff

function main.actions.socket(string url = "kateadams.eu", string path = "/")
	local socket = require("luaflare.socket.posix")
	local util = require("luaflare.util")
	
	do
		local sock = assert(socket.connect(url, 80))
		sock:write(table.concat({
			"GET "..path.." HTTP/1.1",
			"Host: "..url,
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
		local content, _, part = sock:read("a", length, 1)
		content = content or part
		print("read:", content:len())
		print()
	end
	do return end
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
end

return main
