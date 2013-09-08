hook = {}
hook.hooks = {}

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
	
	for k,func in pairs(hooktbl) do
		local ret = {pcall(func, ...)}
		
		if ret[1] then
			table.remove(ret, 1)
			
			if #ret ~= 0 then -- if there was a return value, return it, otherwise continue calling the hooks
				return unpack(ret)
			end
		else
			hook.Call("LuaError", {pcall_res = ret, params = {...}})
		end
	end
end
