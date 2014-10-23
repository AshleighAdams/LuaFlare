local configor = require("configor")
local util = require("luaserver.util")

local script = {}

function script.pid() -- attempt to locate the PID of the process
	return posix.getpid("pid")
end

script.instance_names = {}
script.instance_names_last = 0

function script.instance()
	local ret = script.instance_names[coroutine.running()]
	if not ret then
		script.instance_names_last = script.instance_names_last + 1
		script.instance_names[coroutine.running()] = "unnamed: " .. script.instance_names_last
		ret = script.instance_names[coroutine.running()]
	end
	return script.pid() .. ":" .. ret
end

--[[ -- enable this to check for things slowing coroutines down
local real_resume = coroutine.resume
local real_yield = coroutine.yield
local co_depth = {}

function coroutine.resume(co, ...)
	table.insert(co_depth, util.time())
	return real_resume(co, ...)
end

function coroutine.yield(...)
	local t = util.time() - table.remove(co_depth, #co_depth)
	if t > 0.1 then
		print((t*1000).."ms", debug.traceback())
	end
	return real_yield(...)
end
]]

function script.current_file(depth)
	return debug.getinfo((depth or 1) + 1).source:sub(2)
end

function script.current_path(depth)
	return debug.getinfo((depth or 1) + 1).source:sub(2):Path()
end

function script.local_path(path) expects "string"
	return (script.current_path(2):match("(sites/.-/).*") or "") .. path
end

function script.instance_info()
	return string.format("on %d", script.pid())
end

script.options = {}
script.arguments = {}
script.filename = ""
script.cfg_blacklist = {
	version = true,
	help = true,
	config = true,
	["out-pid"] = true,
	["unit-test"] = true
}

function script.parse_arguments(args, shorthands) expects "table"
	script.filename = args[0]
	shorthands = shorthands or {}
	
	for k, v in ipairs(args) do
		local long_set, val = v:match("^%-%-(.+)=(.+)$")
		local long = v:match("^%-%-(.+)$")
		local short = v:match("^%-(.+)$")
		
		if long_set then
			script.options[long_set] = val
		elseif long then
			script.options[long] = true
		elseif short then
			local opts = short
			for i = 1, opts:len() do
				local opt = opts:sub(i, i)
				local key = shorthands[opt] or opt
				script.options[key] = true
			end
		else
			table.insert(script.arguments, v)
		end
	end
	
	-- if --config is set, then load and update it
	if type(script.options.config) == "string" then
		local save_config = false
		local path = script.options.config
		
		print(string.format("loading options from %s", path))
		local cfg, err = configor.loadfile(path)
		
		if err then
			warn(string.format("%s:%s", path, err))
			os.exit(1)
		end
		
		for _, node in pairs(cfg.arguments:children()) do
			local name, value = node:name(), node:data()
			local new = script.options[name]
			
			if script.cfg_blacklist[name] ~= nil then
				-- ignore this...
			elseif new == nil then -- not updating anything, retreive the stored option...
				script.options[name] = value
			elseif new ~= nil and new ~= value then
				-- a new value was specified, update the config's value
				new = tostring(new)
				print(string.format("updating %s's %s with \"%s\" (was \"%s\")", path, name, new, value))
				cfg.arguments[name]:set_value(new)
				save_config = true
			else
				-- param matches that of the config...
			end
		end
		
		-- add any none-existing-config arguments
		for name, value in pairs(script.options) do
			if script.cfg_blacklist[name] == nil and cfg.arguments[name]:data() ~= tostring(value) then
				print(string.format("new option %s in %s with value \"%s\"", name, path, value))
				cfg.arguments[name]:set_value(value)
				save_config = true
			end
		end
		
		if save_config then
			print(string.format("writing configuration changes to %s", path))
			configor.savefile(cfg, path)
		end
	end
end

return script
