local luaflare = require("luaflare")

local session = {}
local posix = require("posix")
local meta = {}
meta._meta = {__index = meta}

local session_path = luaflare.config_path .. "/sessions/"

session.valid_chars = "AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz0123456789"
session.valid_pattern = string.format("^[%s]+$", session.valid_chars)
local function random_string(length)
	local ret = {}
	local max = session.valid_chars:len()
	for i = 1, length do
		local rand = math.secure_random(1, max)
		table.insert(ret, session.valid_chars:sub(rand, rand))
	end

	return table.concat(ret)
end

function session.get(req, res, string session_name = "session")
	local id = req:get_cookie(session_name)

	if id ~= nil then -- make sure it contains only valid chars!
		if not id:match(session.valid_pattern) then
			warn("%s sent an invalid session id!", req:peer())
			id = nil
		end
	end

	local ret = setmetatable({}, meta._meta)
	ret:construct(req, res, session_name, id)
	return ret
end

function meta:construct(req, res, session_name, id)
	if id == nil then
		-- try to make a unique ID, by generating an ID, and checking it doesn't already exist
		while true do -- generate one
			id = random_string(32)
			if table.load(session_path .. session_name .. "_" .. id) == nil then
				break
			end
			warn("session: generation: collision")
		end

		print("session: new: " .. req:peer() .. ": " .. id)
		table.save({}, session_path .. session_name .. "_" .. id)
		res:set_cookie(session_name, id)
	end

	self._id = id
	self._session_name = session_name
	self._data = table.load(session_path .. session_name .. "_" .. id)

	if self._data == nil then
		warn("%s sent a none-existing (expired?) session id!", req:peer())
		self:construct(req, res, session_name, nil) -- force the generation of a new session
	end
end

function meta:save()
	util.ensure_path("sessions/")
	table.save(self:data(), session_path .. self._session_name .. "_" .. self:id())
end

function meta:id()
	return self._id
end

function meta:data()
	return self._data
end

return session

