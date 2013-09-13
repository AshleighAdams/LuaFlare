-- All extensions to inbuilt libs use ThisCase

local posix = require("posix")

-- incase these libs wen't created
table = table or {}
string = string or {}
escape = escape or {}
script = script or {}

------ Table functions
function PrintTable(tbl, done, depth)
	if tbl == nil then error("argument #1 is nil", 2) end
	
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

function table.Count(tbl)
	if tbl == nil then error("argument #1 is nil", 2) end
	
	local count = 0
	for k,v in pairs(tbl) do
		count = count + 1
	end
	
	return count
end

function table.IsEmpty(tbl)
	if tbl == nil then error("argument #1 is nil", 2) end
	
	for k,v in pairs(tbl) do
		return false
	end
	return true
end

function table.HasKey(tbl, key) -- if not tbl[key] then -- < is an error if is 0 or false
	if tbl == nil then error("argument #1 is nil", 2) end
	
	return tbl[key] ~= nil
end

function table.HasValue(tbl, value)
	if tbl == nil then error("argument #1 is nil", 2) end
	
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
	if table.IsEmpty(tbl) then return "{}" end
	
	depth = depth or 1
	done = done or {}
	done[tbl] = true
	
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

function table.ToString(tbl)
	if tbl == nil then error("argument #1 is nil", 2) end
	
	return to_lua_table(tbl)
end

------- String functions

function string.StartsWith(haystack, needle)
	return haystack:sub(1, needle:len()) == needle
end

function string.EndsWith(haystack, needle)
	return needle == "" or haystack:sub(-needle:len()) == needle
end

function string.Trim(str, chars)
	error("Not implimented", 2)
end

function string.Replace(str, what, with)
	return str:gsub(escape.pattern(what), escape.pattern(with))
end

function string.Path(self)
	return self:match("(.+/)") or ""
end

------- escape functions, try not to use string.Replace, as it is slower than raw gsub

function escape.pattern(input) -- defo do not use string.Replace, else revusion err
	if input == nil then error("argument #1 is nil", 2) end
	
	input = input:gsub("%%", "%%%%") -- escape %'s, and others
	
	input = input:gsub("%.", "%%.")
	input = input:gsub("%*", "%%*")
	input = input:gsub("%(", "%%(")
	input = input:gsub("%)", "%%)")
	input = input:gsub("%+", "%%+")
	
	return input
end

function escape.html(input, strict)
	if input == nil then error("argument #1 is nil", 2) end
	
	if strict == nil then strict = true end
	
	input = input:gsub("&", "&amp;")
	input = input:gsub('"', "&quot;")
	input = input:gsub("'", "&apos;")
	input = input:gsub("<", "&lt;")
	input = input:gsub(">", "&gt;")
	
	if strict then
		input = input:gsub("\t", "&nbsp;&nbsp;&nbsp;&nbsp;")
		input = input:gsub("\n", "<br />\n")
	end
	return input
end

function escape.sql(input)
	if input == nil then error("argument #1 is nil", 2) end
	
	input = input:gsub("'", "\\'")
	input = input:gsub("\"", "\\\"")
	
	return input
end

------- os.*

function os.capture(cmd, raw)
	local f = assert(io.popen(cmd .. " 2>&1", 'r')) -- TODO: should always redirect?
	local s = assert(f:read('*a'))
	local _, _, err_code = f:close()
	if raw then return s, err_code end
	s = string.gsub(s, '^%s+', '')
	s = string.gsub(s, '%s+$', '')
	s = string.gsub(s, '[\n\r]+', ' ')
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

------- script.*
local _pid = nil
function script.pid() -- attempt to locate the PID of the process
	if _pid ~= nil then return _pid end
	
	if posix ~= nil then
		_pid = posix.getpid("pid")
		return _pid
	end
	
	local stat = io.open("/proc/self/stat")
	
	if not stat then
		_pid = -1
		local contents = stat:read("*all")
		local sb = contents:match("(%d+)") -- get the first number
		
		_pid = tonumber(sb) or -2
	else
		_pid = -1
		stat:close()
	end
	
	return _pid
end

function script.current_file(depth) -- 0 = caller, 1 = caller's parent, 2 = caller's caller's parent
	return debug.getinfo((depth or 0) + 2).source
end

function script.instance_info()
	return string.format("on %d", script.pid())
end

script.options = {}
script.arguments = {}
script.filename = ""

function script.parse_arguments(args)
	script.filename = args[0]
	
	for k, v in ipairs(args) do
		local long_set, val = v:match("--(%w+)=(%w+)")
		local long = v:match("--(%w+)")
		local short = v:match("-(%w+)")

		if long_set then
			script.options[long_set] = val
		elseif long then
			script.options[long] = true
		elseif short then
			local opts = short
			for i = 0, opts:len() do
				script.options[opts[i]] = true
			end
		else
			table.insert(script.arguments, v)
		end
	end
end

local stack
do
	local meta = {}
	meta._meta = {__index = meta}
	
	function stack()
		local ret = {_tbl = {}}
		return setmetatable(ret, meta._meta)
	end
	
	function meta:push(val)
		table.insert(self._tbl, val)
	end
	
	function meta:pop()
		table.remove(self._tbl, 1)
	end
	
	function meta:value()
		return self._tbl[1]
	end
	
	function meta:all()
		return self._tbl
	end
end

-- detour print, so that it appends the PID infront
local old_print = print
function print(first, ...)
	local pid = tostring(script.pid()) .. ": "
	if first == nil then
		return old_print(pid, ...)
	else
		return old_print(pid .. tostring(first), ...)
	end
end

local stacks = stack()
local current = stack()

function include(file)
	local path = file:Path()
	file = file:sub(path:len())

	current:push((current:value() or "") .. path)
		for k,v in ipairs(stacks:all()) do
			v(current:value() .. file)
		end
		
		local deps = {}
		local function on_dep(dep)
			table.insert(deps, dep)
		end
		
		stacks:push(on_dep)
			dofile(current:value() .. file)
		stacks:pop()
	current:pop()
	
	return deps
end

