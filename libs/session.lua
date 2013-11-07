
local session = {}
local posix = require("posix")
local meta = {}
meta._meta = {__index = meta}

session.valid_chars = "AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz0123456789"
local function random_string(length)
	local ret = ""
	local max = session.valid_chars:len()
	for i = 1, length do
		local rand = math.SecureRandom(1, max)
		ret = ret .. session.valid_chars:sub(rand, rand)
	end

	return ret
end

function session.get(req, res, session_name)
	session_name = session_name or "session"
	local id = req:get_cookie("session")

	if id ~= nil then -- make sure it contains only valid chars!
		if not id:match(string.format("^[%s]+$", session.valid_chars)) then
			print(req:peer() .. " sent an invalid session id!")
			id = nil
		end
	end

	if id == nil then
		id = random_string(32)
		res:set_cookie(session_name, id)
	end

	local ret = setmetatable({}, meta._meta)
	ret:construct(id)
	return ret
end

function meta:construct(id)
	self._id = id
	self._data = table.load("sessions/" .. id) or {}
end

function meta:save()
	util.EnsurePath("sessions/")
	table.save(self:data(), "sessions/" .. self:id())
end

function meta:id()
	return self._id
end

function meta:data()
	return self._data
end

return session

