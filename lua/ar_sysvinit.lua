local script = require("luaserver.util.script")
local hook = require("luaserver.hook")

local function out_pid()
	if script.options["out-pid"] ~= nil then
		local f = io.open(script.options["out-pid"], "w")
		f:write(tostring(script.pid()))
		f:close()
		print("wrote PID to " .. script.options["out-pid"])
	end
end

hook.add("Loaded", "output pid", out_pid, 2)
