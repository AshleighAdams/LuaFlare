local mimetypes = require("mimetypes")
local httpstatus = require("httpstatus")

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

function meta:request() expects(meta)
	return self._request
end

function meta:client() expects(meta)
	return self._client
end

function meta:set_status(what) expects(meta, "number")
	assert(self and what)
	self._status = what
end

function meta:append(str) expects(meta, "string")
	self._reply = self._reply .. str
end

function meta:clear() expects(meta)
	assert(self)
	self._status = 200
	self._content_type = "text/html"
	self._reply = ""
	self.file = nil
end

function meta:set_file(path, from, to) expects(meta, "string")
	local file = io.open(path, "rb")
	
	if not file then
		hook.Call("Error", {type = 404}, self:request(), self)
		return false
	end
	
	self:set_header("Content-Type", mimetypes.guess(path) or "text/html")
	self._file = path
	
	self._reply = file:read("*all")
	file:close()
	
	if from ~= nil then
		local len = self._reply:len()		
		if len < from or (to ~= nil and len < to) then
			-- we can't serve this
			self:set_status(httpstatus.fromstring("Requested Range Not Satisfiable"))
			-- tell them how long the file is
			self:set_header("Content-Range", "bytes */" .. len)
			self._reply = "" -- nulify the response
		else
			if to == nil then to = len end
			
			self:set_status(httpstatus.fromstring("Partial Content"))
			-- subtract one to convert from 1 index to 0 index; C "a[n]" == Lua "a[n + 1]"
			self:set_header("Content-Range", string.format("bytes %i-%i/%i", from - 1, to - 1, len))
			self._reply = self._reply:sub(from, to)
		end
	end
	
	return true
end

function meta:set_header(name, value) expects(meta, "string", "*")
	assert(self)
	self._headers[name] = tostring(value)
end

-- finish
function meta:send() expects(meta)
	if self._sent then return end -- we've already sent it
	self._sent = true -- mark future calls to send as done
	
	self:set_header("Content-Length", self._reply:len())
	
	local tosend = "HTTP/1.1 " .. tostring(self._status) .. (httpstatus.tostring(self._status) or "") .. "\n"
	for k,v in pairs(self._headers) do
		tosend = tosend .. tostring(k) .. ": " .. tostring(v) .. "\n"
	end
	
	tosend = tosend .. "\n" .. self._reply
	
	self:client():send(tosend)
	self._client = nil -- prevent circular recusion? i duno if not doing this will mem leak
	self._request = nil -- doesn't harm us not to...
end