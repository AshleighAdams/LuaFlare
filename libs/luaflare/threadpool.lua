
local threadpool = {}
threadpool._meta = {__index = threadpool}

function threadpool.create(number threads, function func)
	local tp = {}
	tp.queue = {}
	tp.quit = false
	tp.func = func
	tp.routines = {}
	tp.added = 0
	tp.finished = 0
	
	tp.thread_function = function()
		xpcall(function()
			while not tp.quit do
				func(tp:dequeue())
				tp.finished = tp.finished + 1
			end
		end, function(err)
			-- () around coroutine.running() to force ignore the 2nd ret value, might not be needed, but better safe than sorry
			local costr = tostring( (coroutine.running()) ):match("0x(.+)")
			warn("thread %s died: %s", costr, err)--, debug.traceback())
		end)
	end
	
	for i=1, threads do
		local co = coroutine.create(tp.thread_function)
		script.instance_names[co] = tostring(i)
		table.insert(tp.routines, co)
	end
	print("created " .. threads .. " threads")
	
	return setmetatable(tp, threadpool._meta)
end

function threadpool::enqueue(any object)
	self.added = self.added + 1
	table.insert(self.queue, object)
end

function threadpool::dequeue()
	while not self.quit do
		local obj = self.queue[1]
		if obj ~= nil then
			table.remove(self.queue, 1)
			return obj
		else
			coroutine.yield()
		end
	end
end

function threadpool::done()
	return self.added == self.finished
end

function threadpool:step()
	for i, co in ipairs(self.routines) do
		if coroutine.status(co) ~= "dead" then -- shouldnt happen
			local suc, err = coroutine.resume(co)
			if not suc then
				warn("%s\n%s", err, debug.traceback(co))
			end
		else
			warn("coroutine %d died, remaking...", i)
			table.remove(self.routines, i)
			local co = coroutine.create(self.thread_function)
			script.instance_names[co] = tostring(i)
			table.insert(self.routines, co)
		end
	end
end

return threadpool
