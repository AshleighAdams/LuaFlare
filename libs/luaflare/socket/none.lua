
local socket = {}
socket.backend = "none"
socket.api_version = "0.2"

-- these metatables must be here, as other's may be detouring them
socket.client = {}
socket.listener = {}

local client, listener = socket.client, socket.listener

-- Server side, for listenered sockets

-- returns either (nil, err) or (listener)
function socket.listen(string address = "*", number port = 0)
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
function listener::accept(number timeout = -1)
	error("not imp")
end

-- the port we're listening on, if socket.bind was passed 0, this will be assigned by the OS
function listener::port()
	error("not imp")
end

function listener::address()
	error("not imp")
end

-- stop listening
function listener::close()
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
limit:
	== 0: no limit
	> 0: max bytes
timeout: same as in accept
returns: (data) or (nil, err, partial)
]]
function client::read(string format = "a", number limit = 0, number timeout = -1)
	error("not imp")
end

function client::write(string data, number from = 1, number to = -1)
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
