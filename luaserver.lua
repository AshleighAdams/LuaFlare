#!/usr/bin/env lua5.1

dofile("hooks.lua")
dofile("htmlwriter.lua")
dofile("requesthooks.lua")

local socket = require( "socket" )
local url = require( "socket.url" )


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


function ReadHeaders(client)
	local ret = {}
	
	while true do
		local s, err = client:receive("*l")
		
		if s == "" then break end
		if s ~= nil then
			local key, val = string.match(s, "(.+): (.+)")
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

function HandleClient(client)
	local action = client:receive("*l")
	local headers = ReadHeaders(client)
	
	local method, full_url, version = string.match(action, "(%w+) (.+) HTTP/([0-9.]+)")
	
	local parsed_url = url.parse(full_url)
	local url = url.unescape(parsed_url.path)
	
	parsed_url.params = parse_params(parsed_url.params)
	
	local request = {
		client = client,
		method = method,
		url = url,
		full_url = full_url,
		parsed_url = parsed_url,
		headers = headers
	}
	local response = {}
	
	--PrintTable(request)
	
	hook.Call("Request", request, response)
end

local function on_error(why, request, response)
	print("error:", why.type, request.full_url)
end
hook.Add("Error", "log errors", on_error)

local server = socket.bind("*", 27015)
while true do
	local client = server:accept()
	HandleClient(client)
	client:close()
end


