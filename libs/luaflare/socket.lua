
local socket = {}

socket.client = {}
socket.bound = {}

local client, bound = socket.client, socket.bound

-- Server side, for bounded sockets

-- returns either (nil, err) or (bound)
function socket.bind(number port = 0, string to = "*")
	error("not imp")
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
	error("not imp")
end

function client::hostname()
	error("not imp")
end

function client::port()
	error("not imp")
end

-- lua socket uses send/receive, i dislike those, it should just be read/write to a stream
--[[ format is:
	"l", "*l": line,
	"a", "*a": end of stream
length:
	== 0: no length
	> 0: max length
]]
function client::read(string format = "a", number length = 0)
	error("not imp")
end

function client::write(string data)
	error("not imp")
end

function client::close()
	error("not imp")
end

return socket
