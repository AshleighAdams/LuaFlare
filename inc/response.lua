local mimetypes = require("mimetypes")
local httpstatus = require("httpstatus")
local md5 = require("md5")
require("lfs")

local meta = {}
meta.__index = meta

function Response(request)
	if not request then error("request expected", 2) end
	local ret = {_status = 200, _reply = "", _headers = {}, _request = request, _client = request:client()}
	setmetatable(ret, meta)
	
	ret:set_header("Server", "luaserver")
	ret:set_header("Connection", request:headers().Connection or "close")
	ret:set_header("Content-Type", "text/html")
	
	return ret
end

function meta::request()
	return self._request
end

function meta::client()
	return self._client
end

function meta::set_status(number what)
	assert(self and what)
	self._status = what
end

function meta::append(string str)
	self._reply = self._reply .. str
end

function meta::clear()
	assert(self)
	self._status = 200
	self._content_type = "text/html"
	self._reply = ""
	self.file = nil
	self._tosend_cookies = nil
end

function meta::clear_headers()
	self._headers = {}
end

function meta::clear_content()
	local status = self._status
	self:clear()
	self._status = status
end

function meta::set_file(string path)-- expects(meta, "string")
	local file = io.open(path, "rb")
	
	if not file then
		hook.Call("Error", {type = 404}, self:request(), self)
		return false
	end
	
	self:set_header("Content-Type", mimetypes.guess(path) or "text/html")
	self._file = path
	
	if script.options["x-accel-redirect"] ~= nil then
		file:close()
		self:set_header("X-Accel-Redirect", script.options["x-accel-redirect"] .. path)
		return
	elseif script.options["x-sendfile"] ~= nil then
		file:close()
		local fullpath = lfs.currentdir() .. "/" .. path
		self:set_header("X-Sendfile", fullpath)
		return
	else
		self._reply = file:read("*all")
		file:close()
	end
	
	do -- support for HTTP Range
		local req = self:request()
		local headers = req:headers()
		
		local range_from, range_to = nil, nil
		if headers.Range ~= nil then
			if headers.Range:Trim() == "" then
				res:set_header("Accept-Ranges", "bytes") -- let them know that we can accept ranges
			else
				local from, to = string.match(headers.Range, "bytes=(%d+)-(%d*)")
				local len = self._reply:len()
				
				print("client wants range " .. from .. " to " .. tostring(to))
				from = tonumber(from) or 0
				to = tonumber(to) or len - 1
				
				-- okay, serve the ranged file (if we can)
				if len <= from  or len <= to then
					-- we can't serve this
					self:set_status(httpstatus.fromstring("Requested Range Not Satisfiable"))
					-- tell them how long the file is
					self:set_header("Content-Range", "bytes */" .. len)
					self._reply = "" -- nulify the response
				else
					self:set_status(httpstatus.fromstring("Partial Content"))
					self:set_header("Content-Range", string.format("bytes %i-%i/%i", from, to, len))
					
					-- add one to convert from 0 index to 1 index; C "a[n]" == Lua "a[n + 1]"
					self._reply = self._reply:sub(from + 1, to + 1)
				end
			end
		end
	end
	
	return true
end

function meta::set_header(string name, * value) -- expects(meta, "string", "*")
	name = util.canonicalize_header(name)
	self._headers[name] = tostring(value)
end

function meta::remove_header(string name)
	name = util.canonicalize_header(name)
	self._headers[name] = nil
end

function meta::set_cookie(string name, string value, path, domain, lifetime)
	self._tosend_cookies = self._tosend_cookies or {}
	self._tosend_cookies[name] = {value=value, lifetime=lifetime, path=path, domain=domain}

end

function meta::etag()
	return string.format([[W/"%s"]], md5.sumhexa(self._reply))
end

local max_etag_size
function meta::use_etag()
	if max_etag_size == nil then
		local multi = {k = 1, M = 2, G = 3, T = 4, P = 5, E = 6, Z = 7, Y = 8}
		local tmp = script.options["max-etag-size"] or "64 MiB"
		tmp = tmp:gsub(" ", "")

		local number, postfix, twentyfour, bitbyte = tmp:match("(%d+)([A-z]?)(i?)([Bb]?)")
		number = tonumber(number)

		bitbyte = bitbyte == "b" and 8 or 1
		multi = multi[postfix] or 1
		multi = twentyfour == "i" and (1024 ^ multi) / bitbyte or (10 ^ (multi * 3)) / bitbyte

		max_etag_size = number * multi
	end

	return self._status == 200 and (self._reply:len()) < max_etag_size
end

-- finish
local x_powered_by = _VERSION:gsub("Lua ", "Lua/")
function meta::send()
	if self._sent then return end -- we've already sent it
	self._sent = true -- mark future calls to send as done
	
	self:set_header("Content-Length", self._reply:len())
	self:set_header("X-Powered-By", x_powered_by)
	
	-- ETag support
	local ifnonematch = self:request():headers()["If-None-Match"]
	if self:use_etag() then
		local etag = self:etag()
		if ifnonematch ~= nil and ifnonematch == etag then -- they've supplied an etag, and it matches
			self._reply = ""
			self:remove_header("Content-Length")
			self:set_status(304)
		end
		self:set_header("ETag", etag)
	end

	-- write headers
	local tosend = "HTTP/1.1 " .. tostring(self._status) .. " " .. (httpstatus.tostring(self._status) or "") .. "\r\n"
	for k,v in pairs(self._headers) do
		tosend = tosend .. tostring(k) .. ": " .. tostring(v) .. "\r\n"
	end

	-- cookies
	if self._tosend_cookies ~= nil then
		for name, tbl in pairs(self._tosend_cookies) do
			local optionstr

			if tbl.lifetime ~= nil then
				local ends_at = os.time() + tbl.lifetime
				local format = "%a, %d %b %Y %X UTC"
				local timestring = os.date(format, ends_at)

				optionstr = (optionstr and optionstr .. " " or "") .. string.format("expires=%s;", timestring)
			end

			if tbl.path then
				optionstr = (optionstr and optionstr .. " " or "") .. string.format("path=%s;", tbl.path)
			end

			tosend = tosend .. string.format("Set-Cookie: %s=%s%s\r\n", name, tbl.value, optionstr and "; " .. optionstr or "")
		end
	end

	if self:request():method() == "HEAD" then
		self._reply = "" -- HEAD should yield same headers, but no body
	end
	tosend = tosend .. "\r\n" .. self._reply
	
	local client = self:client()
	client:settimeout(-1)
	
	client:send(tosend)
	
	self._client = nil -- prevent circular recusion? i duno if not doing this will mem leak
	self._request = nil -- doesn't harm us not to...
end
