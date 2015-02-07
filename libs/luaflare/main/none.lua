local model = {}

local main = require("luaflare.main")
local scheduler = require("luaflare.scheduler")
local hook = require("luaflare.hook")
local util = require("luaflare.util")
local script = require("luaflare.util.script")

local socket = require("socket")

function model.listen(table options)
	local server, err = assert(socket.bind(options.host, options.port))
	local next_reloadscripts = util.time() + options.reload_time
	
	hook.call("Load")
	
	while true do
		local to = math.min(options.max_wait, scheduler.idletime())
		if to < 0 then
			to = options.max_wait
		end
		server:settimeout(to)
		
		local client = server:accept()
		
		if not options.no_reload and util.time() > next_reloadscripts then
			hook.safe_call("ReloadScripts")
			next_reloadscripts = util.time() + options.reload_time
		end
		
		if client then
			main.handle_socket(client)
		end
		
		scheduler.run()
	end
end

return model
