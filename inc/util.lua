-- All extensions to inbuilt libs use ThisCase

local posix = require("posix")
local socket = require("socket")

--# luarocks install xssfilter
-- And until luarocks supports lua 5.2:
--# cp /usr/local/share/lua/5.1/xssfilter.lua /usr/local/share/lua/5.2/xssfilter.lua
require("xssfilter")
local xss_filter = xssfilter.new({})

-- incase these libs wen't created
table = table or {}
string = string or {}
math = math or {}
escape = escape or {}
script = script or {}
util = util or {}

------ Table functions
function PrintTable(tbl, done, depth) expects "table"
	
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

function table.Count(tbl) expects "table"	
	local count = 0
	for k,v in pairs(tbl) do
		count = count + 1
	end
	
	return count
end

function table.IsEmpty(tbl) expects "table"	
	return next(tbl) == nil
end

function table.HasKey(tbl, key) expects ("table", "*")
	return tbl[key] ~= nil
end

function table.HasValue(tbl, value) expects ("table", "*")	
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
	
	if depth > 10 then return "..." end
	
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

function table.ToString(tbl) expects "table"
	
	return to_lua_table(tbl)
end

------- String functions

function string.StartsWith(haystack, needle) expects ("string", "string")
	return haystack:sub(1, needle:len()) == needle
end

function string.EndsWith(haystack, needle) expects ("string", "string")
	return needle == "" or haystack:sub(-needle:len()) == needle
end

function string.Replace(str, what, with) expects ("string", "string", "string")
	return str:gsub(escape.pattern(what), escape.pattern(with))
end

function string.Path(self) expects "string"
	return self:match("(.*/)") or ""
end

function string.ReplaceLast(str, what, with) expects ("string", "string", "string")
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

function string.Trim(str) expects "string"
	return str:match("^%s*(.-)%s*$")
end

function string.Split(self, delimiter) expects("string", "string")
	delimiter = escape.pattern(delimiter)
	
	local result = {}
	local from  = 1
	local delim_from, delim_to = string.find(self, delimiter, from)
	while delim_from do
		table.insert(result, string.sub(self, from , delim_from-1 ))
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

function math.Round(what, prec)
	prec = prec or 1
	expects("number", "number")
	
	prec = 1 / prec
	return basic_round(what * prec) / prec
end

------- escape functions, try not to use string.Replace, as it is slower than raw gsub

function escape.pattern(input) expects "string" -- defo do not use string.Replace, else revusion err	
	return (string.gsub(s, "[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1"))
end

function escape.html(input, strict) expects "string"
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

function escape.striptags(input, tbl) expects "string"
	local html, message = xss_filter:filter(input)
	
	if html then
	   return html
	elseif message then
		error(message)
	end
	error("what?")
end

function escape.sql(input) expects "string"	
	input = input:gsub("'", "\\'")
	input = input:gsub("\"", "\\\"")
	
	return input
end

function escape.argument(input) expects "string"
	input = input:gsub(" ", "\\ ")	
	input = input:gsub("'", "\\'")
	input = input:gsub("\"", "\\\"")
	input = input:gsub("\n", "\\n")
	input = input:gsub("\r", "\\r")
	input = input:gsub("\b", "\\b")
	input = input:gsub("\t", "\\t")
	
	return input
end

------- os.*

function os.capture(cmd, raw) expects "string"
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
function script.pid() -- attempt to locate the PID of the process
	return posix.getpid("pid")
end

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
			for i = 0, opts:len() do
				local opt = opts:sub(i, i)
				local key = shorthands[opt] or opt
				script.options[key] = true
			end
		else
			table.insert(script.arguments, v)
		end
	end
end


----- util.*
function util.time()
	return socket.gettime()
end

function util.ItterateDir(dir, recursive, callback, ...) expects("string", "boolean", "function")
	assert(dir and recursive ~= nil and callback)
	
	for file in lfs.dir(dir) do
		if lfs.attributes(dir .. file, "mode") == "file" then
			callback(dir .. file, ...)
		elseif recursive and file ~= "." and file ~= ".." and lfs.attributes(dir .. file, "mode") == "directory" then
			itterate_dir(dir .. file .. "/", recursive, callback, ...)
		end
	end
end

function util.DirExists(dir) expects "string"
	return lfs.attributes(dir, "mode") == "directory"
end

function util.Dir(base_dir, recursive) expects "string"
	local ret = {}
	
	local itt_dir = function(dir)
		for filename in lfs.dir(dir) do
			if filename ~= "." and filename ~= ".." then
			
				local file = dir .. file
				if util.DirExists(file) then
					table.insert(ret, {name=file .. "/", dir=true})
					if recursive then itt_dir(file .. "/") end
				else
					table.insert(ret, {name=file, dir=false})
				end
				
			end
		end
	end
	
	itt_dir(base_dir)
	return ret
end

function util.EnsurePath(path) expects "string" -- false = already exists, true = didn't
	if util.DirExists(path) then return false end
	
	local split = path:Split()
	local cd = ""
	
	for k,v in ipairs(split) do
		cd = cd .. v .. "/"
		
		if not util.DirExists(path) then
			assert(lfs.makedir(cd))
		end
	end
	
	return true
end
----- other

local stack
do
	local meta = {}
	meta._meta = {__index = meta}
	
	function stack()
		local ret = {_tbl = {}}
		return setmetatable(ret, meta._meta)
	end
	
	function meta:push(val) expects (meta._meta)
		table.insert(self._tbl, val)
	end
	
	function meta:pop() expects (meta._meta)
		table.remove(self._tbl, 1)
	end
	
	function meta:value() expects (meta._meta)
		return self._tbl[1]
	end
	
	function meta:all() expects (meta._meta)
		return self._tbl
	end
end

-- detour print, so that it appends the PID infront
static_print = print
function print(first, ...)
	local pid = tostring(script.pid()) .. ": "
	if first == nil then
		return static_print(pid, ...)
	else
		return static_print(pid .. tostring(first), ...)
	end
end

local stacks = stack()
local current = stack()

function include(file) expects "string"
	local path = file:Path()
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
			dofile(current:value() .. file)
		stacks:pop()
	current:pop()
	
	return deps
end

expects_types = {}
expects_types.vector = function(what) -- example
	if what == nil then return false, "is nil" end
	if type(what.x) ~= "number" then return false, "x not defined" end
	if type(what.y) ~= "number" then return false, "y not defined" end
	if type(what.z) ~= "number" then return false, "z not defined" end
	return true
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
		elseif type(arg) == "table" then -- should be a meta table
			if val == nil then
				error(string.format("argument #%i (%s) expected a table with a metatable (got nil)", i, name), err_level)
			end
			
			local meta = getmetatable(val)
			if meta ~= arg then
				error(string.format("argument #%i (%s): metatable mismatch", i, name), err_level)
			end
		elseif arg == "*" then -- anything but nil
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
