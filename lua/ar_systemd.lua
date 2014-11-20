-- Tell systemd that we've loaded
local script = require("luaflare.util.script")
local hook = require("luaflare.hook")
local scheduler = require("luaflare.scheduler")
--[[
# luarocks install systemd
# ln -s /usr/local/share/lua/5.1/systemd /usr/local/share/lua/5.2/systemd
# ln -s /usr/local/lib/lua/5.1/systemd /usr/local/lib/lua/5.2/systemd
]]

local function systemd_notify()
	if not script.options.systemd then return end
	
	local daemon = require("systemd.daemon")
	
	local interval = daemon.watchdog_enabled()
	if interval then
		local function heartbeat()
			local delay = interval / 2
			while true do
				daemon.kick_dog()
				coroutine.yield(delay)
			end
		end
		
		scheduler.newtask("systemd heartbeat", heartbeat)
		print("systemd heartbeat beating")
	end
	
	io.stdout:write("notifying systemd...")
	if daemon.notify(false, "READY=1\nSTATE=Listening") then
		io.stdout:write(" okay\n")
	else
		io.stdout:write(" fail\n")
	end
end

-- priority is 2, therefore
hook.add("Loaded", "notify systemd", systemd_notify, 2)
