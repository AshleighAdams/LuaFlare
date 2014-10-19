local util = require("luaserver.util")
local script = require("luaserver.util.script")

local scheduler = {}
scheduler.tasks = {}

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
				warn("scheduler: warning: %s: took %ds to execute!", tbl.name, t)
			end
			
			if not isnoterr then -- something went wrong
				table.remove(scheduler.tasks, k)
				
				-- did it die of natural causes?
				if ret ~= "cannot resume dead coroutine" then
					warn("scheduler: Lua error: %s", ret)
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

function scheduler.idle()
	local t = util.time() + 0.1
	for k, tbl in pairs(scheduler.tasks) do
		if tbl.nexttime < t then
			t = tbl.nexttime
		end
	end
	
	t = t - util.time()
	posix.nanosleep(0, t * 1000000000)
end

function scheduler.done()
	return #scheduler.tasks == 0
end

return scheduler
