local mimetypes = require("inc.mimetypes")

local meta = {}
meta.__index = meta

function Response(request)
	if not request then error("request expected", 2) end
	local ret = {_status = 200, _reply = "", _headers = {}, _request = request, _client = request:client()}
	setmetatable(ret, meta)
	
	ret:set_header("Server", "luaserver")
	ret:set_header("Content-Type", "text/html")
	
	return ret
end

function meta:request()
	return self._request
end

function meta:client()
	return self._client
end

function meta:set_status(what)
	assert(self and what)
	self._status = what
end

function meta:append(str)
	self._reply = self._reply .. str
end

function meta:clear()
	assert(self)
	self._status = 200
	self._content_type = "text/html"
	self._reply = ""
	self.file = nil
end

function meta:set_file(path)
	if type(path) ~= "string" then error("argument #1, string expected, got " .. type(path), 2) end
	assert(self)
		
	local file = io.open(path, "rb")
	
	if not file then
		hook.Call("Error", {type = 404}, self:request(), self)
		return false
	end
	
	self:set_header("Content-Type", mimetypes.guess(path) or "text/html")
	self._file = path
	self._reply = file:read("*all")
	file:close()
	return true
end

function meta:set_header(name, value)
	if name == nil then error("argument #1 expected string, got nil", 2) end
	if value == nil then error("argument #2 expected string, got nil", 2) end
	assert(self)
	self._headers[name] = value
end

-- finish
function meta:send()
	self:set_header("Content-Length", self._reply:len())
	
	local tosend = "HTTP/1.1 " .. tostring(self._status) .. "\n"
	for k,v in pairs(self._headers) do
		tosend = tosend .. tostring(k) .. ": " .. tostring(v) .. "\n"
	end
	
	tosend = tosend .. "\n" .. self._reply
	
	self:client():send(tosend)
	self._client = nil -- prevent circular recusion? i duno if not doing this will mem leak
	self._request = nil -- doesn't harm us not to...
end