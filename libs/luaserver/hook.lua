local hook = {}
hook.hooks = {}
hook.fatal_section = 0

hook.Add = function(hookname, name, func)
	local hooktbl = hook.hooks[hookname]
	if hooktbl == nil then
		hooktbl = {}
		hook.hooks[hookname] = hooktbl
	end
	
	hooktbl[name] = func
end

hook.Remove = function(hookname, name)
	local hooktbl = hook.hooks[hookname]
	if hooktbl == nil then
		return
	end
	hooktbl[name] = nil
end

hook.Call = function (name, ...)
	local hooktbl = hook.hooks[name]
	if hooktbl == nil then
		return
	end
	
	for k, func in pairs(hooktbl) do
		local ret = {func(...)}
		if #ret ~= 0 then
			return unpack(ret)
		end
	end
end

hook.SafeCall = function (name, ...)
	local hooktbl = hook.hooks[name]
	if hooktbl == nil then
		return
	end
	
	for k,_func in pairs(hooktbl) do
		local args = {...}
		local func = _func -- make a reference, so that inside on_error, it always referes to this itteration
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
			hook.Call("LuaError", msg, trace, vars, args)
		else -- if there was a return value, return it, otherwise continue calling the hooks
			table.remove(ret, 1)
			if #ret ~= 0 then
				return unpack(ret)
			end
		end
	end
end

return hook
