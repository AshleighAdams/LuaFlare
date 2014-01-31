scheduler = {}
scheduler.tasks = {}

function scheduler.newtask(name, func) expects("string", "function")
	table.insert(scheduler.tasks, {name = name, co = coroutine.create(func)})
end

function scheduler.run()
	for k, tbl in pairs(scheduler.tasks) do
		local co = tbl.co
		local st = util.time()
		local _, err = coroutine.resume(co)
		local et = util.time()
		
		if et - st > 0.5 then -- warn if > 0.5 seconds...
			print(string.format("scheduler: warning: %s: took %ds to execute!", tbl.name, (et-st)))
		end
		
		if err then -- something went wrong
			table.RemoveValue(scheduler.tasks, co)
			
			-- did it die of natural causes?
			if err ~= "cannot resume dead coroutine" then
				print(string.format("scheduler: Lua error: %s", err))
			end
		end
	end
end

function scheduler.done()
	return #scheduler.tasks == 0
end