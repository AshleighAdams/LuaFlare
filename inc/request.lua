local url = require("socket.url")
local socket = require("socket")
local httpstatus = require("httpstatus")

local meta = {}
meta.__index = meta

local trusted_proxies = {}
for _, hostname in pairs ((script.options["trusted-reverse-proxies"] or "localhost"):Split(",")) do
	-- potentially look up the IP
	trusted_proxies[hostname] = true
	local resolved, info = socket.dns.toip(hostname)
	
	if not resolved then
		print(string.format("trusted reverse proxy: could not resolve %s: %s", hostname, info))
	else
		for k,ip in pairs(info.ip) do
			trusted_proxies[ip] = true
			print(string.format("trusted reverse proxy: %s (%s)", ip, hostname))
		end
	end
end

local function quick_response(request, err, why)
	local response = Response(request)
	response:halt(err, why)
	response:send()
	return why
end

local function quick_response_client(client, err)
	local errstr = httpstatus.know_statuses[err] or "Unknown"
	client:send(string.format("HTTP/1.1 %d %s\r\n", err, errstr))
	client:send("Server: luaserver\r\n")
	client:send("Content-Length: 0\r\n")
	client:send("\r\n")
end

-- TODO: replace error messages with something meaningful
function Request(client) -- expects("userdata")
	local action, err = client:receive("*l")
	if not action then return nil end -- just timed out
	
	local method, full_url, version = string.match(action, "(%w+) (.+) HTTP/([%d.]+)")
	version = tonumber(version)
	
	local parsed_url
	-- is the host embedded in the GET path? (HTTP 1.2 and up only)
	if version >= 1.2 and not full_url:StartsWith("/") then
		parsed_url = url.parse(full_url)
	else
		-- add a dot at the front of the path to ensure that it is treated as a path, and not a full URL.
		parsed_url = url.parse("." .. full_url)
		parsed_url.path = parsed_url.path:sub(2) -- remove the dot we added.
	end
	
	if method == nil or full_url == nil or version == nil then
		quick_response_client(client, 400) 
		return nil, "invalid request: failed to parse method, url, or version"
	end
	
	local headers, err = read_headers(client, version, parsed_url)
	if not headers then
		quick_response_client(client, 400)
		return nil, "invalid request: failed to parse headers: " .. err
	end
	
	local peer = client:getpeername():match("^(.+):?%d*$") -- cpature .+, : is optional, and digits are optional
	if script.options["reverse-proxy"] then
		if not trusted_proxies[peer] then
			quick_response_client(client, 403) -- forbidden
			return nil, "reverse-proxy: " .. peer .. " is not trusted!"
		end
		
		peer = headers["X-Real-IP"]
		if not peer then return nil, "X-Real-IP not set!" end
	end
	
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
		_peer = peer,
		_version = version
	}
	
	setmetatable(request, meta)
	
	local maxpostlength = tonumber(script.options["max-post-length"])
	
	-- read the post data
	if method == "GET" or method == "HEAD" then
	elseif method == "POST" then
		local len = tonumber(request:headers()["Content-Length"])
		
		if len == nil then -- send them a length required
			return nil, quick_response(request, 411, "Length required")
		elseif maxpostlength ~= nil and len > maxpostlength then
			return nil, quick_response(request, 413, "Maximum post data length exceeded")
		end
		
		local post, err = client:receive(tonumber(len))
		if post == nil then
			return nil, quick_response(request, 400, "Failed to read post data (" .. len .. " bytes): " .. err)
		end
		
		request._post_string = post
	else
		return nil, quick_response(request, 501, method .. " not supported")
	end
	
	return request
end

function meta::method()
	return self._method
end

function meta::params()
	return self._params
end

function meta::post_data()
	if self._post_data == nil then
		self._post_data = parse_params(self._post_string)
	end
	return self._post_data
end

function meta::post_string()
	return self._post_string
end

function meta::headers()
	return self._headers
end

function meta::url()
	return self._url
end

function meta::full_url()
	return self._full_url
end

function meta::parsed_url()
	return self._parsed_url
end

function meta::client()
	return self._client
end

function meta::start_time()
	return self._start_time
end

function meta::total_time()
	return util.time() - self._start_time
end

function meta::peer()
	return self._peer
end

function meta::parse_cookies()
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

function meta::get_cookie(string name)
	if not self._cookies then self:parse_cookies() end
	return self._cookies[name]
end

-- some util stuff we need
function meta::is_upgraded()
	return self.upgraded == true
end

function meta::set_upgraded()
	self.upgraded = true
end

function read_headers(client, version, url)
	local ret = {}
	local lastheader = nil
	
	while true do
		local s, err = client:receive("*l")
		
		if not s or s == "" then break end
		
		if s:sub(1,1) == " " or s:sub(1,1) == "\t" then -- this is a continuation from the previous line
			if not lastheader then
				return nil, "can't append to last header (absent)"
			end
			ret[lastheader] = ret[lastheader] .. " " .. val:Trim() -- i think the space should go here
		else -- This isn't a continuation, parse new header
			local key, val = string.match(s, "([%a%-]-):%s*(.+)")
			if key ~= nil then
				key = util.canonicalize_header(key) -- normalize it!
				lastheader = key
				if ret[key] == nil then
					ret[key] = val
				else
					ret[key] = string.format("%s, %s", ret[key], val)
				end
			else
				-- TODO: check the spec for what should be done
				return nil, "null key for header specified"
			end
		end
	end
	
	if version == 1.0 then
		-- host not needed in 1.0
	elseif version == 1.1 then
		if not ret.Host then -- this MUST be sent!
			return nil, "client failed to send Host header"
		end
	elseif version >= 1.2 then
		local authority = url.authority
		
		if authority then
			if ret.Host then -- check they're the same, error if they're not; not sure what the spec says I should do
				if authority ~= ret.Host then
					return nil, string.format("host header (%s) != URL authority (%s)",
						ret.Host, authority)
				end
			else -- Host: wasn't set, set it to authority
				ret.Host = authority
			end
		end
		
		if not ret["Host"] then -- this MUST be sent!
			return nil, "client failed to send Host header or set absolute URL"
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
