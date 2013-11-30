local url = require("socket.url")
local socket = require("socket")

local meta = {}
meta.__index = meta

local function quick_response(request, err)
	local response = Response(request)
	response:set_status(err)
	response:send()
end

local function quick_response_client(client, err)
	client:send("HTTP/1.1 " .. tostring(err) .. "\n")
	client:send("Server: luaserver\n")
	client:send("Content-Length: 0\n")
	client:send("\n")
end

-- TODO: replace error messages with something meaningful
function Request(client) -- expects("userdata")
	local action, err = client:receive("*l")
	if not action then return nil end -- just timed out
	
	local method, full_url, version = string.match(action, "(%w+) (.+) HTTP/([%d.]+)")
	if method == nil or full_url == nil or version == nil then
		quick_response_client(client, 400) 
		return nil, "invalid request: failed to parse method, url, or version"
	end
	
	local headers = read_headers(client)
	if not headers then quick_response_client(client, 400) return nil, "invalid request: failed to parse headers" end
	
	local peer = client:getpeername():match("^(.+):?%d*$") -- cpature .+, : is optional, and digits are optional
	if script.options["local"] then
		peer = headers["X-Forwarded-For"]
		if not peer then return nil, "X-Forwarded-For not set!" end
	end
	
	local parsed_url = url.parse(full_url)
		
	local request = {
		_client = client,
		_method = method,
		_url = url.unescape(parsed_url.path),
		_full_url = full_url,
		_parsed_url = parsed_url,
		_headers = headers,
		_params = parse_params(parsed_url.query),
		_post_data = nil,
		_post_string = "",
		_start_time = util.time(),
		_peer = peer
	}
	
	setmetatable(request, meta)
	
	-- read the post data
	if method == "GET" or method == "HEAD" then
	elseif method == "POST" then
		local len = request:headers()["Content-Length"]
		
		if len == nil then -- send them a length required
			quick_response(request, 411)
			return nil, "Length required"
		end
		
		local post, err = client:receive(tonumber(len))
		if post == nil then quick_response(request, 400) return nil, "failed to read post data (" .. len .. ") bytes: " .. err end
		
		request._post_string = post
	else
		quick_response(request, 501)
		return  nil, method .. " not supported"
	end
	
	return request
end

function meta:method() expects(meta)
	return self._method
end

function meta:params() expects(meta)
	return self._params
end

function meta:post_data() expects(meta)
	if self._post_data == nil then
		self._post_data = parse_params(self._post_string)
	end
	return self._post_data
end

function meta:post_string() expects(meta)
	return self._post_string
end

function meta:headers() expects(meta)
	return self._headers
end

function meta:url() expects(meta)
	return self._url
end

function meta:full_url() expects(meta)
	return self._full_url
end

function meta:parsed_url() expects(meta)
	return self._parsed_url
end

function meta:client() expects(meta)
	return self._client
end

function meta:start_time() expects(meta)
	return self._start_time
end

function meta:total_time() expects(meta)
	return util.time() - self._start_time
end

function meta:peer() expects(meta)
	return self._peer
end

function meta:parse_cookies() expects(meta)
	local cookie_str = self:headers().Cookie or ""
	self._cookies = {}

	--for str in cookie_str:gmatch("%s*.-%s*=%s*.-%s*;?") do
	for _, str in pairs(cookie_str:Split(";")) do
		local pos = string.find(str, "=", 1, true)
		if pos ~= nil then
			local key = str:sub(1, pos - 1):Trim()
			local val = str:sub(pos + 1):match("(.+);?"):Trim()
			self._cookies[key] = val
		end
	end
end

function meta:get_cookie(name) expects(meta, "string")
	if not self._cookies then self:parse_cookies() end
	return self._cookies[name]
end

-- some util stuff we need

function read_headers(client)
	local ret = {}
	
	while true do
		local s, err = client:receive("*l")
		
		if not s or s == "" then break end

		local key, val = string.match(s, "([%a%-]-):%s*(.+)")
		if key ~= nil then
			ret[key] = val
		else
			-- TODO: check the spec for what should be done
			return nil
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