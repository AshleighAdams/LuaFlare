
local socket = {}
socket.backend = "none"
socket.api_version = "0.1"

-- these metatables must be here, as other's may be detouring them
socket.client = {}
socket.bound = {}

local client, bound = socket.client, socket.bound

-- Server side, for bounded sockets

-- returns either (nil, err) or (bound)
function socket.bind(number port = 0, string address = "*")
	return nil, "not implimented"
end

-- host is in the format (host|ipv4|ipv6)[:port]
function socket.connect(string host, number port)
	return nil, "not implimented"
end

-- timeout < 0: forever;
-- timeout == 0: non-blocking
-- timeout > 0: seconds to wait
-- port: 0 = OS assigns
-- returns (client) or (nil, err_reason)
function bound::accept(number timeout = -1)
	error("not imp")
end

-- the port we're listening on, if socket.bind was passed 0, this will be assigned by the OS
function bound::port()
	error("not imp")
end

-- stop listening
function bound::close()
	error("not imp")
end

-- type, backend (i.e, websocket, luaflare; tcp, luasocket; tcp, posix)
function client::type()
	return "none", "luaflare", socket.api_version
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

-- TODO: should i do this? (using sendfile())
-- function client::writefile(string path, number start = 0, number length = -1)

function client::flush(number timeout = -1)
end

function client::close()
	error("not imp")
end

return socket
