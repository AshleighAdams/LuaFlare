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

if imp.api_version ~= none.api_version then
	local msg = string.format("backend = %s %s latest = %s", imp.backend, imp.api_version, none.api_version)
	warn("socket backend version differs: %s", msg)
end

if not metatable_compatible(none, imp) then
	local _, err = metatable_compatible(none, imp)
	error("socket backend not compatible: " .. err)
elseif not metatable_compatible(none.client, imp.client) then
	local _, err = metatable_compatible(none.client, imp.client)
	error("socket client backend not compatible: " .. err)
elseif not metatable_compatible(none.listener, imp.listener) then
	local _, err = metatable_compatible(none.listener, imp.listener)
	error("socket listener backend not compatible: " .. err)
end

return imp
