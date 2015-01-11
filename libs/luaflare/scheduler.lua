local scheduler = {}
scheduler.tasks = {}

local util = require("luaflare.util")
local script = require("luaflare.util.script")

function scheduler.newtask(string name, function func) -- expects("string", "function")
	table.insert(scheduler.tasks, {
		name = name,
		co = coroutine.create(func),
		nexttime = util.time(),
		born = util.time(),
		
		exectime = 0,
		lasttickrate = 60,
	})
end

scheduler.tick_rate = 1 / ( tonumber(script.options["scheduler-tick-rate"]) or 60 )
function scheduler.run()
	local t = util.time()
	for k, tbl in pairs(scheduler.tasks) do
		if t > tbl.nexttime then
			local co = tbl.co
			local st = util.time()
			local isnoterr, ret = coroutine.resume(co)
			local t = util.time() - st
			
			if t > 0.5 then -- warn if > 0.5 seconds...
				warn("scheduler: warning: %s: took %.2fs to execute!", tbl.name, t)
			end
			
			if not isnoterr then -- something went wrong
				table.remove(scheduler.tasks, k)
				
				-- did it die of natural causes?
				if ret ~= "cannot resume dead coroutine" then
					warn("scheduler: Lua error: %s\n%s", ret, debug.traceback(co))
				end
			else
				-- run scheduler.tick_rate times per second by default
				tbl.nexttime = util.time() + (ret or scheduler.tick_rate)
				
				tbl.lasttickrate = (ret or scheduler.tick_rate)
				tbl.exectime = tbl.exectime + t
			end
		end
	end
end

function scheduler.idletime()
	local t
	for k, tbl in pairs(scheduler.tasks) do
		if t == nil or tbl.nexttime < t then
			t = tbl.nexttime
		end
	end
	
	return t == nil and -1 or math.max(0, t - util.time())
end

function scheduler.done()
	return #scheduler.tasks == 0
end

return scheduler
