#!/usr/bin/env lua5.1

dofile("inc/hooks.lua")
dofile("inc/htmlwriter.lua")
dofile("inc/lua_icon_base64.lua")
dofile("inc/requesthooks.lua")

local socket = require("socket")
local url = require("socket.url")
require("lfs")


function PrintTable(tbl, done, depth)
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

function is_empty_tbl(tbl)
	for k,v in pairs(tbl) do
		return false
	end
	return true
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
	if is_empty_tbl(tbl) then return "{}" end
	
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


function read_headers(client)
	local ret = {}
	
	while true do
		local s, err = client:receive("*l")
		
		if not s or s == "" then break end
		if s ~= nil then
			local key, val = string.match(s, "([%a-]+):%s*(.+)")
			ret[key] = val
		end
	end
	
	return ret
end

function parse_params(str)
	local ret = {}
	
	if not str then return ret end
	
	local current_name = ""
	local current_value = ""
	local in_name = true
	
	local function add_kv()
		ret[url.unescape(current_name)] = url.unescape(current_value)
		current_name = ""
		current_value = ""
	end
	
	for i = 1, str:len() do
		local char = str:sub(i, i)
		if char == "+" then char = " " end
		
		if in_name then
			if char == '=' then
				in_name = false
			elseif char == '&' then
				add_kv()
			else
				current_name = current_name .. char
			end
		else
			if char == '&' then
				add_kv()
				in_name = true
			else
				current_value = current_value .. char
			end
		end
	end
	
	add_kv()
	return ret
end


function html_escape(str, strict)
	if strict == nil then strict = true end
	
	str = str:gsub("&", "&amp;")
	str = str:gsub('"', "&quot;")
	str = str:gsub("'", "&apos;")
	str = str:gsub("<", "&lt;")
	str = str:gsub(">", "&gt;")
	
	if strict then
		str = str:gsub("\t", "&nbsp;&nbsp;&nbsp;&nbsp;")
		str = str:gsub("\n", "<br />\n")
	end
	return str
end

----------------------------------- response portion
local response_meta = {}

function response_meta:set_status(what)
	assert(self and what)
	self.status = what
end

function response_meta:append(str)
	assert(self ~= nil)
	assert(str ~= nil)
	self.response_text = self.response_text .. str
end

function response_meta:clear()
	assert(self)
	self.response_text = ""
	self.file = nil
end

function response_meta:set_file(path)
	assert(self and path)
	self.file = path
end

function response_meta:set_header(name, value)
	assert(self and name and value)
	self.headers[name] = value
end

---------------- cookie potion TODO: cookies

local cookie_meta = {}

function cookie(name, value, expires)
	local cook = {}
	cook.name = name
	cook.value = value
	cook.expires = expires
end

---------------------------------------------------

function handle_client(client)
	local action = client:receive("*l")
	
	if not action then return end -- failed reading
	
	local headers = read_headers(client)
	local method, full_url, version = string.match(action, "(%w+) (.+) HTTP/([%d.]+)")
	
	local parsed_url = url.parse(full_url)
	local url = url.unescape(parsed_url.path)
	
	parsed_url.params = parse_params(parsed_url.query)
	
	print(method .. " " .. url)
	
	local request = {
		client = client,
		method = method,
		url = url,
		full_url = full_url,
		parsed_url = parsed_url,
		headers = headers
	}
	local response = {status = 200, response_text = "", headers = {}}
	setmetatable(response, {__index = response_meta})
	
	response:set_header("Server", "LuaServer2")
	
	hook.Call("Request", request, response)
	
	-- must be after...
	response:set_header("Content-Type", "text/html")
	response:set_header("Content-Length", (function() 
		if not response.file then
			return response.response_text:len() + 1
		else 
			error("file not implimented yet" .. tostring(response.file))
		end
	end)())

	
	
	local tosend = "HTTP/1.1 " .. tostring(response.status) .. "\n"
	for k,v in pairs(response.headers) do
		tosend = tosend .. tostring(k) .. ": " .. tostring(v) .. "\n"
	end
	
	tosend = tosend .. "\n\n"
	
	if not response.file then
		tosend = tosend .. response.response_text
	end
	
	client:send(tosend)
end

local function on_error(why, request, response)
	response:set_status(why)
	print("error:", why.type, request.full_url)
end
hook.Add("Error", "log errors", on_error)

local function on_lua_error(err, trace, args)
	print("lua error:", err)
end
hook.Add("LuaError", "log errors", on_lua_error)

require'lfs'

local function starts_with(what, with)
	return what:sub(1, with:len()) == with
end

local function ends_with(what, with)
	return with == "" or what:sub(-with:len()) == with
end

local function autorun(dir)
	dir = dir or "lua/"
	for file in lfs.dir("./lua/") do
		if lfs.attributes(dir .. file, "mode") == "file" then
			if starts_with(file, "ar_") and ends_with(file, ".lua") then
				print("autorun: " .. dir .. file)
				dofile(dir .. file)
			end
		elseif file ~= "." and file ~= ".." and lfs.attributes(dir .. file, "mode") == "directory" then
			autorun(dir .. file .. "/")
		end
	end
end
autorun()

local server = socket.bind("*", 27015)
while true do
	local client = server:accept()
	client:settimeout(1)
	
	handle_client(client)
	client:close()
end


