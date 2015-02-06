local threadpool = require("luaflare.threadpool")
local scheduler = require("luaflare.scheduler")
local hook = require("luaflare.hook")
local script = require("luaflare.util.script")
local escape = require("luaflare.util.escape")
local reload_time = script.options["reload-time"] or 5

do
	local depth = 1
	while true do
		if not pcall(debug.getlocal, depth + (1 + 2), 1) then break end -- + 1 for next, itt, + 2 for pcall scopes
		depth = depth + 1
	end
	
	local version = tonumber(_VERSION:match("[%d%.]+"))
	local _ENV = _ENV
	
	if version <= 5.1 then
		-- simulate _ENV
		_ENV = setmetatable({}, {__newindex = function(self, k, v)
			getfenv()[k] = v
		end})
	end
	
	local i = 1
	while true do
		local name, val = debug.getlocal(depth, i)
		if name ~= nil then
			_ENV[name] = val
		else
			break
		end
		i = 1 + i
	end
end

function main_loop()
	local server, err = socket.bind(host, port)
	assert(server, err)
	
	hook.safe_call("ReloadScripts") -- load all of our scritps, before forking anything!
	local next_reloadscripts = util.time()
	
	hook.call("Load")
	
	local profiler = require("luaflare.profiler")
	
	while true do
		server:settimeout(scheduler.idletime())
		local client = server:accept()
		
		if not script.options["no-reload"] and util.time() > next_reloadscripts then
			hook.safe_call("ReloadScripts")
			next_reloadscripts = util.time() + reload_time
		end
		
		if client then
			profiler.start()
			if not handle_client(client) then
				client:close()
			end
			profiler.stop()
		end
		
		scheduler.run()
	end
	
end
