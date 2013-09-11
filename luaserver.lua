#!/usr/bin/env lua5.1

dofile("inc/hooks.lua")
dofile("inc/htmlwriter.lua")
dofile("inc/lua_icon_base64.lua")
dofile("inc/requesthooks.lua")

local socket = require("socket")
local url = require("socket.url")
local ssl = require("ssl")
local mimetypes = require("inc.mimetypes")

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
			
			if key == nil then error("HTTP request is invalid", 2) end
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
	if type(path) ~= "string" then error("argument #1, string expected, got " .. type(path), 2) end
	assert(self)
	
	local file = io.open(path, "rb")
	
	if not file then
		hook.Call("Error", {type = 404}, self.request, self)
		return false
	end
	
	self.file = path
	self.response_text = file:read("*all")
	file:close()
	return true
end

function response_meta:set_header(name, value)
	if name == nil then error("argument #1 expected string, got nil", 2) end
	if value == nil then error("argument #1 expected string, got nil", 2) end
	assert(self)
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
		headers = headers,
		post_data = {}
	}
	
	-- read the post data
	if method == "POST" then
		local len = request.headers["Content-Length"]
		
		if len == nil then
			client:close()
			return
		end
		
		local post = client:receive(tonumber(len))
		if post == nil then return end
		
		request.post_data = parse_params(post)
	end
	
	-- respond
	
	local response = {status = 200, response_text = "", headers = {}, request = request}
	setmetatable(response, {__index = response_meta})
	
	response:set_header("Server", "LuaServer2")
	
	hook.Call("Request", request, response)
	
	-- must be after...
	local type = response.file and mimetypes.guess(response.file) or "text/html"
	local len = response.response_text:len()
	
	response:set_header("Content-Type", type)
	response:set_header("Content-Length", len)
		
	local tosend = "HTTP/1.1 " .. tostring(response.status) .. "\n"
	for k,v in pairs(response.headers) do
		tosend = tosend .. tostring(k) .. ": " .. tostring(v) .. "\n"
	end
	
	tosend = tosend .. "\n" .. response.response_text
	
	client:send(tosend)
end
hook.Add("HandleClient", "default handle client", handle_client)

local function on_error(why, request, response)
	response:set_status(why.type)
	print("error:", why.type, request.url)
end
hook.Add("Error", "log errors", on_error)

local function on_lua_error(err, trace, args)
	print("lua error:", err)
end
hook.Add("LuaError", "log errors", on_lua_error)



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

local https = false
local params = {
	mode = "server",
--	protocol = "tlsv1",
	protocol = "sslv3",
	key = "keys/key.pem",
	certificate = "keys/certificate.pem",
--	cafile = "keys/request.pem", -- uncomment these lines if you want to verify the client
--	verify = {"peer", "fail_if_no_peer_cert"},
	options = {"all", "no_sslv2"},
	ciphers = "ALL:!ADH:@STRENGTH",
}

function main()
	local server, err = socket.bind("*", 8080)
	assert(server, err)
	-- so we can spawn many processes
	--server:setoption("reuseport", true)
	
	while true do
		local client = server:accept()
		client:settimeout(1)
		
		if https then
			client, err = ssl.wrap(client, params)
			assert(client, err)
			
			local suc, err = client:dohandshake()
			if not suc then print("ssl failed: ", err) end
		end
		
		hook.Call("HandleClient", client)
		client:close()
	end
end

main() -- then let us run in it