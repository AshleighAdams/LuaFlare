
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

	local ret = setmetatable({}, meta._meta)
	ret:construct(req, res, session_name, id)
	return ret
end

function meta:construct(req, res, session_name, id)
	if id == nil then		
		while true do -- generate one
			id = random_string(32)
			if table.load("sessions/" .. session_name .. "_" .. id) == nil then
				break
			end
		end

		print(req:peer() .. " generated a new sesion id: " .. id)
		table.save({}, "sessions/" .. session_name .. "_" .. id)
		res:set_cookie(session_name, id)
	end

	self._id = id
	self._session_name = session_name
	self._data = table.load("sessions/" .. session_name .. "_" .. id)

	if self._data == nil then
		print(req:peer() .. " sent a none-existing (expired?) session id!")
		self:construct(req, res, session_name, nil) -- force the generation of a new session
	end
end

function meta:save()
	util.EnsurePath("sessions/")
	table.save(self:data(), "sessions/" .. self._session_name .. "_" .. self:id())
end

function meta:id()
	return self._id
end

function meta:data()
	return self._data
end

return session

