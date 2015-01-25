local G = {}

local hook = require("luaflare.hook")

local function check_expects_disabled()
	local script = require("luaflare.util.script")
	
	if not script.options["disable-expects"] then return end
	
	expects = function() end
end
hook.add("Loaded", "expects: --disable-expects", check_expects_disabled)

G.expects_types = {}
G.expects_types.vector = function(what) -- example
	if what == nil then return false, "is nil" end
	if type(what.x) ~= "number" then return false, "x not defined" end
	if type(what.y) ~= "number" then return false, "y not defined" end
	if type(what.z) ~= "number" then return false, "z not defined" end
	return true
end

G.expects_types.character = function(what)
	if what == nil then return false, "is nil" end
	if type(what) ~= "string" then return false, "expected string" end
	if what:len() ~= 1 then return false, "string not of length 1" end
	return true
end

-- duck typing check
function metatable_compatible(base, value)
	if value == nil then return false, "is nil" end
	--if base == getmetatable(value) then return true end
	
	-- MAYBE: Ignore ignore __index, __newindex, and __call?
	for k,v in pairs(base) do
		if type(v) == "function" then
			local func = value[k]
			if not func or type(func) ~= "function" then
				return false, string.format("function missing: %s", k)
			end
		end
	end
	
	return true -- all functions are in existance
end

function G.expects(...)
	local args = {...}
	local count = #args
	local level = 2 -- caller
	local err_level = level + 1
	
	for i = 1, count do
		local arg = args[i]
		local name, val = debug.getlocal(level, i)
		
		if name == nil then -- expects() called with too many args
			error("too many arguments to expects", level)
		end
		
		-- i could call expects_check, but let's leave this here as it won't introduce another call depth
		if arg == nil then -- anything
		elseif type(arg) == "table" then
			local valid, reason = metatable_compatible(arg, val)
			if not valid then
				error(string.format("argument #%i (%s): incompatible (%s)", i, name, reason), err_level)
			end
		elseif arg == "*" then
			error("expects(): \"*\" DEPRICATED!")
		elseif arg == "any" then -- anything but nil
			if val == nil then
				error(string.format("argument #%i (%s) expected a value (got nil)", i, name), err_level)
			end
		elseif expects_types[arg] then
			local good, err = expects_types[arg](val)
			if not good then
				error(string.format("argument #%i (%s) expected %s (%s)", i, name, arg, err), err_level)
			end
		else
			if type(val) ~= args[i] then
				error(string.format("argument #%i (%s) expected %s (got %s)", i, name, arg, type(val)), err_level) -- 3 = caller's caller
			end
		end
	end
end

-- compared to expects(): 70% quicker in lua5.2, luajit: 270% quicker
function G.expects_check(arg, name, val, i)
	if arg == nil then -- anything
	elseif type(arg) == "table" then
		local valid, reason = metatable_compatible(arg, val)
		if not valid then
			error(string.format("argument #%i (%s): incompatible (%s)", i, name, reason), 3)
		end
	elseif arg == "*" then
		error("expects(): \"*\" DEPRICATED!")
	elseif arg == "any" then -- anything but nil
		if val == nil then
			error(string.format("argument #%i (%s) expected a value (got nil)", i, name), 3)
		end
	elseif expects_types[arg] then
		local good, err = expects_types[arg](val)
		if not good then
			error(string.format("argument #%i (%s) expected %s (%s)", i, name, arg, err), 3)
		end
	else
		if type(val) ~= arg then
			error(string.format("argument #%i (%s) expected %s (got %s)", i, name, arg, type(val)), 3) -- 3 = caller's caller
		end
	end
end

return G
