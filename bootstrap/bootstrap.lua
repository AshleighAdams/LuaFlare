-- Upgrade from lua to the current
-- all code here must be compatible with all supported Lua versions (currently 5.2 to 5.3, 5.1 *works*, but is not supported)
-- nothing can be dependant on something outside of this directory, it must be self-contained.

-- global bootstrap
bootstrap = {}

bootstrap.pack = table.pack
bootstrap.unpack = table.unpack

if not bootstrap.pack or bootstrap.unpack then
	function bootstrap.unpack(tbl, i, j)
		local n = tbl.n or #tbl
		i = i or 1
		j = math.min(j or n, n)
	
		local function unpack_it(k)
			if k >= j then
				return tbl[k]
			end
			return tbl[k], unpack_it(k + 1)
		end
		return unpack_it(i)
	end
	function bootstrap.pack(...)
		local t = {...}
		local max
		for k,v in pairs(t) do
			max = k
		end
		t.n = max
		return t
	end
end

bootstrap.options = bootstrap.pack(...)[1]
bootstrap.log_buffer = {}
bootstrap.log_depth = 0
bootstrap.log_deeper = function()
	bootstrap.log_depth = bootstrap.log_depth + 1
end
bootstrap.log_shallower = function()
	bootstrap.log_depth = bootstrap.log_depth - 1
end
bootstrap.log = function(str, ...)
	str = str:format(...)
	table.insert(bootstrap.log_buffer, {text = str, when = os.time(), level = "info", depth = bootstrap.log_depth})
	
	local lb = os.getenv("BOOTSTRAP_LOG")
	if not lb or lb == "" or lb == "0" then return end
	print("bootstrap: " ..("\t"):rep(bootstrap.log_depth).. str)
end
bootstrap.fatal = function(str, ...)
	str = ("\t"):rep(bootstrap.log_depth) .. str:format(...)
	io.stderr:write(str.."\n")
	io.stderr:write(("\t"):rep(bootstrap.log_depth) .. debug.traceback().."\n")
	os.exit(1)
end
bootstrap.loadfile = loadfile -- save a copy, this will be replaced in future
bootstrap.include = function(path, ...)
	path = bootstrap.options.path .."/bootstrap/".. path
	local included, err = loadfile(path)
	if not included then
		bootstrap.fatal("could not include %s: %s", path, err)
	end
	return included(...)
end
bootstrap.module = function(name, path)
	bootstrap.log("installing module %s (%s)", name, path)
	bootstrap.log_deeper()
	local m = assert(bootstrap.include(path), ("failed: %s returned nil"):format(path))
	package.loaded[name] = m
	
	bootstrap.log_shallower()
	return m
end
bootstrap.extend = function(name, path)
	bootstrap.log("extending %s from %s", name, path)
	bootstrap.log_deeper()
	
	local e = assert(bootstrap.include(path), ("failed: %s returned nil"):format(path))
	for k,v in pairs(e) do
		local typeof = _G[name][k] == nil and "installing" or "overwriting"
		bootstrap.log("%s %s.%s", typeof, name, k)
		_G[name][k] = v
	end
	bootstrap.log_shallower()
end
bootstrap.level_string = ""
bootstrap.level_cache = {}
bootstrap.level = function(name, should_error) -- check we are on or above level x
	if bootstrap.level_cache[name] == nil then
		if should_error == nil or should_error then
			bootstrap.fatal("level %s requested, but not availible!", name)
		else
			return false
		end
	end
	return true
end
bootstrap.set_level = function(name)
	if bootstrap.level(name, false) then
		bootstrap.log("set_level called more than once for %s", name)
		return
	end
	
	bootstrap.level_cache[name] = true
	if bootstrap.level_string == "" then
		bootstrap.level_string = name
	else
		bootstrap.level_string = string.format("%s;%s", bootstrap.level_string, name)
	end
	
	bootstrap.log("levels: %s", bootstrap.level_string)
end

------------------------------------------
--        Bootstrap proccess            --
------------------------------------------

do -- for require() to check modules path
	local path = bootstrap.options.path
	bootstrap.log("setting up module paths at %s", path)
	package.path = path .. "/libs/?.lua;" .. package.path
	package.cpath = path .. "/libs/?.so;" .. package.cpath
	bootstrap.set_level("paths")
end

-- dummy expects, will be replaced in future
expects = function() end

	-- 5.1 compat can be used early to bring in 5.2 features
	bootstrap.include("compatibility-5.1.lua")
	
	local hook = bootstrap.module("luaflare.hook", "hook.lua")
	
	-- install our Warning hooks
	hook.add("Warning", "bootstrap", function(str)
		bootstrap.log("warning: %s", str)
	end)
	
bootstrap.set_level("hook")

	bootstrap.module("luaflare.util.luaparser.stringreader", "stringreader.lua")
	bootstrap.module("luaflare.util.luaparser", "luaparser.lua")

bootstrap.set_level("parser")

	bootstrap.module("luaflare.util.stack", "stack.lua")

	bootstrap.extend("_G", "extensions-global.lua")
	bootstrap.extend("_G", "extensions-global-table.lua")
	bootstrap.extend("string", "extensions-string.lua")
	bootstrap.extend("table", "extensions-table.lua")
	bootstrap.extend("math", "extensions-math.lua")
	bootstrap.extend("os", "extensions-os.lua")

bootstrap.set_level("extensions")

	-- must be one of the last
	bootstrap.module("luaflare.util.stack", "stack.lua")
	bootstrap.module("luaflare.util.translate_luacode", "translate-luacode.lua")
	bootstrap.extend("_G", "extensions-global-include.lua")
	bootstrap.include("syntax-extensions.lua")
	
bootstrap.set_level("translator")

	bootstrap.include("compatibility-5.2.lua")
	bootstrap.include("depricated.lua")

bootstrap.set_level("compat")

-- update task name:
do
	bootstrap.log("updating process name")
	bootstrap.log_deeper()
	local f = io.open("/proc/self/comm", "r")
	if f then
		local old = f:read("*l")
		local new = "luaflare"
		
		f:close()
		f = io.open("/proc/self/comm", "w")
		f:write(new)
		f:close()
		bootstrap.log("%s -> %s", old, new)
	end
	bootstrap.log_shallower()
end

-- remove the warning hook
hook.remove("Warning", "bootstrap")

bootstrap.log("complete")

