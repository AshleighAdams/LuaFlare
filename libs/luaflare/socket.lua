-- the reference that the type `socket` will be tested against
local none = require("luaflare.socket.none")
local script = require("luaflare.util.script")

local meta_socket_cache = {}

expects_types.socket = function(value)
	if meta_socket_cache[value] ~= nil then
		return meta_socket_cache[value]
	end
	
	local compat = metatable_compatible(none.client, value)
	
	meta_socket_cache[value] = compat
	
	return compat
end

local backend = script.options["socket-backend"] or "luasocket"
local imp = require("luaflare.socket." .. backend)

local msg = string.format("socket backend: %s %s (latest %s)", imp.backend, imp.api_version, none.api_version)

if imp.api_version == none.api_version then
	print(msg)
else
	warn("socket backend outdated: %s", msg)
end

return imp
