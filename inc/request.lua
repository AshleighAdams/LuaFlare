local url = require("socket.url")
local socket = require("socket")
local httpstatus = require("luaflare.httpstatus")
local hook = require("luaflare.hook")
local util = require("luaflare.util")
local script = require("luaflare.util.script")
local canon = require("luaflare.util.canonicalize-header")
local unescape = require("luaflare.util.unescape")

local meta = {}
meta.__index = meta

local function bits(num, bits)
    local t={}
    while num>0 do
        rest=num%2
        table.insert(t,1,rest)
        num=(num-rest)/2
    end
    
    local ret = table.concat(t)
    return string.rep("0", bits - ret:len()) .. ret
end

local trusted_proxies = {}
local trusted_proxies_mask = {}
local trusted_proxies_mask_cache = {}

local function ip_to_base2(ip)
	local parts = {}
	local is_v6 = ip:match(":") ~= nil
	if is_v6 then
		ip:gsub("[^:]+", function(part)
			table.insert(parts, bits(tonumber(part, 16) or 0, 16))
		end)
		while #parts < 8 do
			table.insert(parts, string.rep("0", 16))
		end
	else
		ip:gsub("%d+", function(part)
			table.insert(parts, bits(tonumber(part, 10), 8))
		end)
	end
	
	return table.concat(parts)
end

local function is_trusted_proxy(ip)
	if trusted_proxies[ip] or trusted_proxies_mask_cache[ip] then
		return true
	end
	
	local binip = ip_to_base2(ip)
	
	for k,v in ipairs(trusted_proxies_mask) do
		if binip:starts_with(v.pattern) then
			trusted_proxies_mask_cache[ip] = true
			print(string.format("trusted reverse proxy cache: %s", ip))
			return true
		end
	end
	
	return false
end

local function load_trusted_proxies()
	for _, hostname in pairs ((script.options["trusted-reverse-proxies"] or "localhost"):split(",")) do
		-- potentially look up the IP
		if hostname:match("/%d+$") then
			local ip, mask = hostname:match("^(.+)/(%d+)$")
			mask = assert(tonumber(mask))
			assert(ip)
			
			local pattern = ip_to_base2(ip):sub(1, mask)
			print(string.format("trusted reverse proxy mask: %s/%d (%s)", ip, mask, pattern))
			
			table.insert(trusted_proxies_mask, {mask = mask, ip = ip, pattern = pattern})
		else
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
	end
end
hook.add("Load", "load trusted reverse proxies", load_trusted_proxies)

-- this is to be used when a response object does not yet exist, and we want to halt.
local function quick_response(request, err, why)
	local response = Response(request)
	response:halt(err, why)
	response:send()
	return why
end

-- this is to be used when a request object has yet to be constructed, and we want to halt.
local function quick_response_socket(socket, err)
	local errstr = httpstatus.tostring(err) or "Unknown"
	socket:write(string.format("HTTP/1.1 %d %s\r\n", err, errstr))
	socket:write("Server: luaflare\r\n")
	socket:write("Content-Length: 0\r\n")
	socket:write("\r\n")
end

-- TODO: replace error messages with something meaningful
local line_max_length = 1024 + 1
local line_timeout = 1
local max_headers = 32

function Request(socket socket) -- expects("userdata")
	local action, err = socket:read("l", line_max_length, line_timeout)
	if not action then return nil end -- just timed out
	if action:len() >= line_max_length then
		quick_response_socket(socket, 414)
		return nil, "URI too long"
	end
	
	local method, full_url, version = string.match(action, "([^ ]+) ([^ ]+) HTTP/([%d.]+)")
	version = tonumber(version)
	
	local parsed_url
	-- is the host embedded in the GET path? (HTTP 1.2 and up only)
	if version >= 1.2 and not full_url:starts_with("/") then
		parsed_url = url.parse(full_url)
	else
		-- add a dot at the front of the path to ensure that it is treated as a path, and not a full URL.
		parsed_url = url.parse("." .. full_url)
		parsed_url.path = parsed_url.path:sub(2) -- remove the dot we added.
	end
	
	-- turn the path into an absolute path
	local canon_path
	do
		local parts = parsed_url.path:split("/\\")
		local curr = {}
		
		for _, part in ipairs(parts) do
			if part == "." then
			elseif part == ".." then
				curr[#curr] = nil
			else
				curr[#curr + 1] = part
			end
		end
		canon_path = table.concat(curr, "/")
	end
	
	--path
	
	if method == nil or full_url == nil or version == nil then
		quick_response_socket(socket, 400) 
		return nil, "invalid request: failed to parse method, url, or version"
	end
	
	local headers, err = read_headers(socket, version, parsed_url)
	if not headers then
		quick_response_socket(socket, 400)
		return nil, "invalid request: failed to parse headers: " .. err
	end
	
	local request = {
		_socket = socket,
		_method = method,
		_path = unescape.url(canon_path),
		_full_url = full_url,
		_parsed_url = parsed_url,
		_headers = headers,
		_params = parse_params(parsed_url.query),
		_post_data = nil,
		_post_string = "",
		_start_time = util.time(),
		_ip = socket:ip(),
		_version = version
	}
	setmetatable(request, meta)
	
	-- update peer
	if script.options["reverse-proxy"] then
		if not is_trusted_proxy(request._ip) then
			return nil, quick_response(request, 403, "reverse-proxy: " .. request._ip .. " is not trusted!")
		end
		
		local ip = headers["X-Real-IP"]
		if not ip then return nil, quick_response(request, 400, "X-Real-IP not set!") end
		request._ip = ip
	end
	
	local maxpostlength = tonumber(script.options["max-post-length"])
	
	
	--[[
		TO DO: impliment a counter
	Assume PUT with a 1GB file, we don't want to load (at min) 1GB into memory,
	instead, it should be processed in chunks, so the concept is:
	
		:content("a")   -- reads ALL content, loads into the 1GB memory
		:content(1024)  -- read in 1KB chunks
	
	returns: data, start_index, end_index
	derive bytes read: end_index - start_index OR data:len()
	derive end of content: end_index == content-length
	]]
	-- read the post data
	if method == "POST" then
		local len = tonumber(request:headers()["Content-Length"])
		
		if len == nil then -- send them a length required
			return nil, quick_response(request, 411, "Length required")
		elseif maxpostlength ~= nil and len > maxpostlength then
			return nil, quick_response(request, 413, "Maximum post data length exceeded")
		end
		
		local post, err = socket:read("a", len)
		if not post then
			return nil, quick_response(request, 400, "Failed to read post data (" .. len .. " bytes): " .. err)
		elseif post:len() ~= len then
			return nil, quick_response(request, 400, string.format("POST: got %d (expected %d)", post:len(), len))
		end
		
		request._post_string = post
	end
	
	return request
end

function meta::method()
	return self._method
end

function meta::params()
	return self._params
end

function meta::post_params()
	if self._post_params == nil then
		self._post_params = parse_params(self._post_string)
	end
	return self._post_params
end

function meta::post_string()
	return self._post_string
end

function meta::headers()
	return self._headers
end

function meta::url()
	warn("request:url() has been deprecated; use :path()")
	return self:path()
end
function meta::path()
	return self._path
end

function meta::full_url()
	return self._full_url
end

function meta::parsed_url()
	return self._parsed_url
end

-- this can't return the socket, as it was a luasocket return value, not a luaflare socket
function meta::client()
	error("client() deprecated, use :socket()", 2)
end
function meta::socket()
	return self._socket
end

function meta::start_time()
	return self._start_time
end

function meta::total_time()
	return util.time() - self._start_time
end

function meta::peer()
	warn("request:peer() deprecated, use request:ip().")
	return self._ip
end

function meta::ip()
	return self._ip
end

function meta::host()
	return self:headers().Host or "localhost"
end

function meta::parse_cookies()
	local cookie_str = self:headers().Cookie or ""
	self._cookies = {}

	--for str in cookie_str:gmatch("%s*.-%s*=%s*.-%s*;?") do
	for _, str in pairs(cookie_str:split(";")) do
		local pos = string.find(str, "=", 1, true)
		if pos ~= nil then
			local key = str:sub(1, pos - 1):trim()
			local val = str:sub(pos + 1):match("(.+);?"):trim()
			self._cookies[key] = val
		end
	end
end

function meta::get_cookie(string name)
	return self:cookies()[name]
end

function meta::cookies()
	if not self._cookies then self:parse_cookies() end
	return self._cookies
end

-- some util stuff we need
function meta::is_upgraded()
	return self.upgraded == true
end

function meta::set_upgraded()
	self.upgraded = true
	self:disown_socket()
end

function meta::owns_socket()
	return not self.is_disowned
end

function meta::disown_socket()
	self.is_disowned = true
end

function meta::__tostring()
	if self._tostr then
		return self._tostr
	else
		local str = string.format("request: %s %s", self:peer(), self:path())
		self._tostr = str
		return str
	end
end

function read_headers(socket, version, url)
	local ret = {}
	local lastheader = nil
	
	local i = 0
	while true do
		i = i + 1
		if i > max_headers then
			return nil, string.format("headers limit execed (%d)", max_headers)
		end
		
		local s, err = socket:read("l", line_max_length, line_timeout)
		
		if not s then
			return nil, err
		elseif s == "" then
			break
		end
		
		local firstchar = s:sub(1,1)
		
		if firstchar == " " or firstchar == "\t" then -- this is a continuation from the previous line
			if not lastheader then
				return nil, "can't append to last header (absent)"
			end
			ret[lastheader] = ret[lastheader] .. " " .. val:trim() -- i think the space should go here
		else -- This isn't a continuation, parse new header
			local key, val = string.match(s, "([^:]+):%s*(.+)")
			if key ~= nil then
				key = canon.get_header(key) -- normalize it!
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
	
	local split = str:split("&")
	for k,v in ipairs(split) do
		local key, value = v:match("(.-)=(.*)")
		if not key then
			key, value = v, ""
		end
		ret[url.unescape(key)] = url.unescape(value)
	end
	
	return ret
end
