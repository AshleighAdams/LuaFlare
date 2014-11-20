-- Tell systemd that we've loaded
local script = require("luaserver.util.script")
local hook = require("luaserver.hook")
local scheduler = require("luaserver.scheduler")
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
		interval = interval / 2 -- half the interval, this is recommended
		
		local function heartbeat()
			daemon.kick_dog()
			return interval
		end
		
		scheduler.newtask("systemd heartbeat", heartbeat)
		print("systemd heardbeat installed")
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
