local hook = {}
hook.hooks = {}

-- rebuilt thee priority table
function hook.invalidate(hookname)
	local hooktbl = hook.hooks[hookname]
	if hooktbl == nil then return end
	
	local callorder = {__mode = "v"} -- weak values
	for k,v in pairs(hooktbl.attached) do
		table.insert(callorder, v)
	end
	table.sort(callorder, function(a,b)
		return a.priority < b.priority
	end)
	hooktbl.callorder = callorder
end

hook.add = function(hookname, name, func, priority)
	priority = priority or 0
	expects("any", "any", "function", "number")
	
	local hooktbl = hook.hooks[hookname]
	if hooktbl == nil then
		hooktbl = {attached = {}, callorder = {}}
		hook.hooks[hookname] = hooktbl
	end
	
	hooktbl.attached[name] = {func = func, name = name, priority = priority}
	hook.invalidate(hookname)
end

hook.remove = function(hookname, name)
	local hooktbl = hook.hooks[hookname]
	if hooktbl == nil then return end
	hooktbl.attached[name] = nil
	hook.invalidate(hookname)
end

hook.call = function (name, ...)
	local hooktbl = hook.hooks[name]
	if hooktbl == nil then
		return
	end
	
	for k, v in ipairs(hooktbl.callorder) do
		local ret = table.pack(v.func(...))
		if #ret ~= 0 then
			return table.unpack(ret)
		end
	end
end

hook.safe_call = function (name, ...)
	local hooktbl = hook.hooks[name]
	if hooktbl == nil then
		return
	end
	
	for k,v in ipairs(hooktbl.callorder) do
		local args = {...}
		local func = v.func -- make a reference, so that inside on_error, it always referes to this itteration
		local bound = function() return func(unpack(args)) end
		
		local function on_error(err)
			local variables = {}
			local idx
			
			-- get the upvalues for the func
			--[[
			idx = 1
			while true do
				local ln, lv = debug.getupvalue(func, idx)
				if ln ~= nil then
					variables[ln] = lv
				else
					break
				end
				idx = 1 + idx
			end
			]]
			
			-- get the locals
			idx = 1
			while true do
				local ln, lv = debug.getlocal(2, idx)
				if ln ~= nil then
					variables[ln] = lv
				else
					break
				end
				idx = 1 + idx
			end
			
			variables["(*temporary)"] = nil
			
			return {err, debug.traceback(), variables}
		end
		
		local ret = {xpcall(bound, on_error)}
		
		if not ret[1] then
			local msg = ret[2][1]
			local trace = ret[2][2]
			local vars = ret[2][3]
			
			warn("Lua error: %s\n%s", msg, trace)
			hook.call("LuaError", msg, trace, vars, args)
		else -- if there was a return value, return it, otherwise continue calling the hooks
			table.remove(ret, 1)
			if #ret ~= 0 then
				return unpack(ret)
			end
		end
	end
end

hook.Call = function(...)
	return hook.call(...)
end

hook.SafeCall = function(...)
	return hook.safe_call(...)
end

hook.Add = function(...)
	return hook.add(...)
end

hook.Remove = function(...)
	return hook.remove(...)
end

return hook
