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
	hook.hooks[hookname] = nil
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
			return unpack(ret)
		end
		
		hook.Call("LuaError", {pcall_res = ret, params = {...}})
	end
end
