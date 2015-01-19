
local socket = {}
socket.backend = "none"
socket.api_version = "2.7" -- the latest version of the "none" backend, that your backend impliments

-- these metatables must be here, as other's may be detouring them
socket.client = {}
socket.bound = {}

local client, bound = socket.client, socket.bound

-- Server side, for bounded sockets

-- returns either (nil, err) or (bound)
function socket.bind(number port = 0, string to = "*")
	return nil, "not implimented"
end

-- timeout < 0: forever;
-- timeout == 0: non-blocking
-- timeout > 0: seconds to wait
-- returns (client) or (nil, err_reason)
function bound::accept(number timeout = -1)
	error("not imp")
end

-- host is in the format (host|ipv4|ipv6)[:port]
function socket.connect(string host)
	return nil, "not implimented"
end

-- type, backend (i.e, websocket, luaflare; tcp, luasocket; tcp, posix)
function client::type()
	return "none", "luaflare"
end

function client::ip()
	error("not imp")
end

function client::port()
	error("not imp")
end

function client::connected()
	return false
end

-- lua socket uses send/receive, i dislike those, it should just be read/write to a stream
--[[ format is:
	"l", "*l": line,
	"a", "*a": end of stream
length:
	== 0: no length
	> 0: max length
timeout: same as in accept
returns: (data) or (nil, err)
]]
function client::read(string format = "a", number length = 0, number timeout = -1)
	error("not imp")
end

function client::write(string data)
	error("not imp")
end

function client::flush()
end

function client::close()
	error("not imp")
end

return socket
