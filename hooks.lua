hook = {}
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

hook.PushFatalErrors = function()
	hook.fatal_section = hook.fatal_section + 1
end

hook.PopFatalErrors = function()
	hook.fatal_section = hook.fatal_section - 1
end

hook.FatalSection = function()
	return hook.fatal_section > 0
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
	
	for k,func in pairs(hooktbl) do
		local args = {...}
		local bound = function() return func(unpack(args)) end
		
		local function on_error(err)
			local variables = {}
			local idx = 1
			while true do
				local ln, lv = debug.getlocal(2, idx)
				if ln ~= nil then
					variables[ln] = lv
				else
					break
				end
				idx = 1 + idx
			end
			
			return {err, debug.traceback(), variables}
		end
		
		local ret
		if hook.FatalSection() then
			ret = {true, bound()}
		else
			ret = {xpcall(bound, on_error)}
		end
		
		if not ret[1] then
			local msg = ret[2][1]
			local trace = ret[2][2]
			local vars = ret[2][3]
			hook.PushFatalErrors()
			hook.Call("LuaError", msg, trace, vars, args)
			hook.PopFatalErrors()
		else -- if there was a return value, return it, otherwise continue calling the hooks
			table.remove(ret, 1)
			if #ret ~= 0 then
				return unpack(ret)
			end
		end
	end
end
