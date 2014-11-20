local configor = require("configor")
local stack = require("luaserver.util.stack")
local escape = require("luaserver.util.escape")
local hook = require("luaserver.hook")
local util

-- All extensions to inbuilt libs use ThisCase
expects_types = {}
expects_types.vector = function(what) -- example
	if what == nil then return false, "is nil" end
	if type(what.x) ~= "number" then return false, "x not defined" end
	if type(what.y) ~= "number" then return false, "y not defined" end
	if type(what.z) ~= "number" then return false, "z not defined" end
	return true
end

-- duck typing check
local function metatable_compatible(base, value)
	if value == nil then return false, "is nil" end
	--if base == getmetatable(value) then return true end
	
	-- MAYBE: Ignore ignore __index, __newindex, and __call?
	for k,v in pairs(base) do
		if type(v) == "function" then
			local func = value[k]
			if not func or type(func) ~= "function" then
				return false, string.format("function %s not found", k)
			end
		end
	end
	
	return true -- all functions are in existance
end

function expects(...)
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


table = table or {}
string = string or {}
math = math or {}

------ Table functions
function print_table(tbl, done, depth) expects "table"
	
	done = done or {}
	depth = depth or 0
	if done[tbl] then return end
	done[tbl] = true
	
	local tabs = string.rep("\t", depth)
	
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			print(tabs .. tostring(k) .. ":")
			PrintTable(v, done, depth + 1)
		else
			print(tabs .. tostring(k) .. " = " .. tostring(v))
		end
	end
end
PrintTable = function(...)
	warn("PrintTable renamed to print_table")
	return print_table(...)
end

function table.count(tbl) expects "table"	
	local count = 0
	for k,v in pairs(tbl) do
		count = count + 1
	end
	
	return count
end

function table.remove_value(tbl, val) expects("table", "any")
	for k, v in pairs(tbl) do
		if v == val then
			table.remove(tbl, k)
		end
	end
end

function table.is_empty(tbl) expects "table"	
	return next(tbl) == nil
end

function table.has_key(tbl, key) expects ("table", "any")
	return tbl[key] ~= nil
end

function table.has_value(tbl, value) expects ("table", "any")	
	for k,v in pairs(tbl) do
		if v == value then
			return true, k
		end
	end
	return false, nil
end


-- Table to string
function to_lua_value(var, notable)
	local val = tostring(var)
	
	if type(var) == "string" then
		val = val:gsub("\\", "\\\\")
		val = val:gsub("\n", "\\n")
		val = val:gsub("\t", "\\t")
		val = val:gsub("\r", "\\r")
		val = val:gsub("\"", "\\\"")
		
		val = "\"" .. val .. "\""
	elseif type(var) == "table" and not notable then
		return to_lua_table(var)
	end
	
	return val
end

local function to_lua_table_key(key)
	if type(key) == "string" then
		if key:match("[A-z_][A-z_0-9]*") == key then
			return key
		end
		return "[" .. to_lua_value(key) .. "]"
	else
		return "[" .. to_lua_value(key) .. "]"
	end
end

function to_lua_table(tbl, depth, done)
	if table.is_empty(tbl) then return "{}" end
	
	depth = depth or 1
	done = done or {}
	done[tbl] = true
	
	if depth > 1024 then return "..." end
	
	local ret = "{\n"
	local tabs = string.rep("\t", depth)
	
	for k, v in pairs(tbl) do
		ret = ret .. tabs .. to_lua_table_key(k) .. " = "
		
		if type(v) ~= "table" or done[v] then
			ret = ret .. to_lua_value(v, true)
		else
			ret = ret .. to_lua_table(v, depth + 1, done)
		end
		
		ret = ret .. ",\n"
	end
	
	-- remove last comma
	ret = ret:sub(1, ret:len() - 2) .. "\n"
	
	tabs = string.rep("\t", depth - 1)
	ret = ret .. tabs .. "}"
	return ret
end

function table.to_string(tbl) expects "table"
	
	return to_lua_table(tbl)
end

------- String functions

function string.begins_with(haystack, needle) expects ("string", "string")
	return haystack:sub(1, needle:len()) == needle
end

function string.ends_with(haystack, needle) expects ("string", "string")
	return needle == "" or haystack:sub(-needle:len()) == needle
end

string.starts_with = string.begins_with
string.stops_with = string.ends_with

function string.replace(str, what, with) expects ("string", "string", "string")
	what = escape.pattern(what)
	with = with:gsub("%%", "%%%%") -- the 2nd arg of gsub only needs %'s to be escaped
	return str:gsub(what, with)
end

function string.path(self) expects "string"
	return self:match("(.*/)") or ""
end

function string.replace_last(str, what, with) expects ("string", "string", "string")
	local from, to, _from, _to = nil, nil
	local pos = 1
	local len = what:len()
	
	while true do
		_from, _to = string.find(str, what, pos, true)
		if _from == nil then break end
		pos = _to
		from = _from
		to = _to
	end
	
	local firstbit = str:sub(1, from - 1)
	local lastbit  = str:sub(to + 1)
	
	return firstbit .. with .. lastbit
end

function string.trim(str) expects "string"
	return str:match("^%s*(.-)%s*$")
end

function string.split(self, delimiter, options) expects("string", "string")
	delimiter = escape.pattern(delimiter)
	
	local result = {}
	local from  = 1
	local delim_from, delim_to = string.find(self, delimiter, from)
	while delim_from do
		local add = true
		local val = self:sub(from, delim_from - 1)
		
		if options and options.remove_empty and val:trim() == "" then
			add = false
		end
		
		if add then table.insert(result, val) end
		from  = delim_to + 1
		delim_from, delim_to = string.find(self, delimiter, from)
	end
	table.insert(result, string.sub(self, from ))
	return result
end

------- math functions
function basic_round(what)
	if what % 1 >= 0.5 then -- haha, the 1 was 0.5, thanks to unit testing i found it...
		return math.ceil(what)
	else
		return math.floor(what)
	end
end

function math.round(what, quantum_size)
	quantum_size = quantum_size or 1
	expects("number", "number")
	
	prec = 1 / prec
	return basic_round(what * quantum_size) / quantum_size
end
	
function math.secure_random(min, max) expects("number", "number")
	-- read from /dev/urandom
	local size = max - min
	local bits = math.ceil( math.log(size) / math.log(2) )
	local bytes = math.ceil( bits / 8 )
	
	local file = io.open("/dev/urandom", "r")

	-- meh, we don't have that device, probably on Windows
	if not file then return math.random(min, max) end
	local data = file:read(bytes)
	file:close()
	
	local result = min
	for i = bytes, 1, -1 do
		
		local byte = data:byte(i)
		result = result + bit32.lshift(byte, (i - 1) * 8)
	end

	if result > max then -- try again, i don't know how else to do this without reducing security
		return math.secure_random(min, max)
	end

	return result
end
------- escape functions, try not to use string.Replace, as it is slower than raw gsub


------- os.*

function os.capture(cmd, opts)
	opts = opts or {stdout = true, stderr = true}
	if opts.stderr and opts.stdout then -- join them
		cmd = cmd .. "2>&1"
	elseif opts.stderr then -- swap 2 (err) for 1(out), and 1 to null
		cmd = cmd .. "2>&1 1>/dev/null"
	elseif opts.stdout then
		
	else -- assume both
		cmd = cmd .. "2>&1"
	end
	
	local f = assert(io.popen(cmd, "r"))
	local s = assert(f:read('*a'))
	local _, _, err_code = f:close()
	return s, err_code
end

local _platform = nil
local _version = 0
function os.platform()
	if _platform then return _platform, _version end
	
	local ret = os.capture("uname -a")
	if ret == nil then
		_platform = "windows"
		_version = 6.1
	elseif ret:find("Linux") then
		_platform = "linux"
		_version = tonumber(table.concat({ret:match("(%d+%.%d+)%.(%d+)")}))
	elseif ret:find("Darwin") then
		_.platform = "mac" -- i hope mac version will work the same
		_version = tonumber(table.concat({ret:match("(%d+%.%d+)%.(%d+)")}))
	else
		_platform = "unknown"
		_version = "0"
	end
	
	return _platform, _version
end




-- detour print, so that it appends the PID infront
--[[
static_print = print

function print(first, ...)
	local id = script.instance()
	static_print(id .." ".. tostring(first), ...)
end
]]

local col_red = "\x1b[31;1m"
local col_reset = "\x1b[0m"
function warn(str, ...) expects("string") -- print a warning to stderr
	if #{...} ~= 0 then
		str = string.format(str, ...)
	end
	
	local outstr = string.format("%s%s%s", col_red, str, col_reset)
	hook.call("Warning", str)
	print(outstr)
end


-- include helpers
dofile = function(file, ...)
	local f = assert(io.open(file, "r"))
	local code = f:read("*a")
	f:close()
	
	code = util.translate_luacode(code)
	local f, err = loadstring(code, file)
	
	if not f then
		warn("failed to loadstring: %s", err)
		return error(err, -1)
	end
	
	return f(...)
end

local stacks = stack()
local current = stack()
function include(file, ...) expects "string"
	package.included = package.included or {}

	local err = nil -- if this != nil at the end, call error with this string
	local path = file:path()
	file = file:sub(path:len() + 1)

	current:push((current:value() or "") .. path)
		for k,v in ipairs(stacks:all()) do
			v(current:value() .. file)
		end
		
		local deps = {}
		local function on_dep(dep)
			table.insert(deps, dep)
		end
		
		stacks:push(on_dep)
			local ret = {pcall(dofile, current:value() .. file, ...)}
			local success = table.remove(ret, 1) -- pcall returns `succeded, f()`, remove the top value
			
			if success == false then -- failed to compile...
				err = ret[1] -- the top of the ret table == the error string
			else -- Add it to the registry
				local file = current:value() .. file
				package.included[file] = package.included[file] or {}

				for k, v in pairs(ret) do
					if type(v) == "table" then
						if package.included[file][k] == nil then
							-- on first itteration, just set it
							package.included[file][k] = v
						else
							-- otherwise, update the values
							local tbl = package.included[file][k]

							-- clear the table
							for k, v in pairs(tbl) do
								tbl[k] = nil
							end
							-- and update with new stuff
							for k, vv in pairs(v) do
								tbl[k] = vv
							end

							ret[k] = tbl
						end
					else
						package.included[file][k] = v
					end
				end
			end
		stacks:pop()
	current:pop()
	
	if err ~= nil then error(string.format("while including: %s: %s", file, err), -1) end
	return unpack(ret), deps
end

util = require("luaserver.util")

local real_require = require
function require(mod)
	if package.loaded[mod] then
		return package.loaded[mod]
	elseif package.preload[mod] then
		return real_require(mod)
	end
	
	local file = package.searchpath(mod, package.path)
	
	if file then
		local m = dofile(file)
		package.loaded[mod] = m
		return m
	end
	
	return real_require(mod)
end



local function renamed_func(tbl, tblname, name, old)
	local func = tbl[name] or error("could not find func " .. name, 2)
	local strn = ("%s.%s"):format(tblname, name)
	local stro = ("%s.%s"):format(tblname, old)
	local msg = ("%s renamed to %s"):format(stro, strn)
	tbl[old] = function(...)
		warn(msg .. "\n" .. debug.traceback())
		return func(...)
	end
end

renamed_func(table, "table", "count", "Count")
renamed_func(table, "table", "remove_value", "RemoveValue")
renamed_func(table, "table", "is_empty", "IsEmpty")
renamed_func(table, "table", "has_key", "HasKey")
renamed_func(table, "table", "has_value", "HasValue")
renamed_func(table, "table", "to_string", "ToString")

renamed_func(string, "string", "starts_with", "StartsWith")
renamed_func(string, "string", "ends_with", "EndsWith")
renamed_func(string, "string", "replace", "Replace")
renamed_func(string, "string", "path", "Path")
renamed_func(string, "string", "replace_last", "ReplaceLast")
renamed_func(string, "string", "trim", "Trim")
renamed_func(string, "string", "split", "Split")

renamed_func(math, "math", "round", "Round")
renamed_func(math, "math", "secure_random", "SecureRandom")






























