
local socket = {}
socket.backend = "posix"
socket.api_version = "0.2"

local block_size = 1500 -- set to the normal MTU
local backlog_size = 32

local posix = require("posix")
local util = require("luaflare.util")

socket.client = {}
socket.listener = {}

local client, listener = socket.client, socket.listener
client.__index = client
listener.__index = listener

warn("The POSIX socket backend does not currently support timeouts!")

local function set_nonblocking(fd)
	local flags = assert(posix.fcntl(fd, posix.F_GETFL), "fnctl: failed to get flags")
	assert(posix.fcntl(fd, posix.F_SETFL, flags | posix.O_NONBLOCK), "failed to set O_NONBLOCK")
end

function socket.listen(string address = "*", number port = 0)
	local addrs, err = posix.getaddrinfo(address, "", {socktype=posix.SOCK_STREAM, flags=posix.AI_PASSIVE})
	if not addrs then return nil, err end
	
	local fd, err, addr
	
	-- the code below ports LuaSocket binding from tcp.c (meth_bind) and inet.c (inet_trybind)
	-- https://github.com/diegonehab/luasocket/blob/d80bb0d82ba105c8fdb27e6174c267965d06ffb0/src/tcp.c#L219
	-- https://github.com/diegonehab/luasocket/blob/d80bb0d82ba105c8fdb27e6174c267965d06ffb0/src/inet.c#L445
	-- TODO: listener could have a list of file descriptors to listen to, allowing IPv4 and IPv6 at the same time
	for k,info in pairs(addrs) do
		info.port = port
		local _fd = posix.socket(info.family, info.socktype, 0)
		
		if _fd then
			local okay, _err, errcode
			okay, _err, errcode = posix.bind(_fd, info)
			
			if not okay then
				posix.close(_fd)
				_fd = nil
				err = _err
			else
				fd = _fd
				addr = info
				break
			end
		end
	end
	if not fd then return nil, string.format("failed to bind: %s", err) end
	
	print("bound to: " .. addr.addr)
		
	local okay, err = posix.listen(fd, backlog_size)
	if not okay then return nil, string.format("failed to listen: %s", err) end
	
	local obj = {
		_fd = fd,
		_port = port,
		_address = address
	}
	
	set_nonblocking(fd)
	return setmetatable(obj, listener)
end

function socket.connect(string host, number port)
	local ips, err = posix.getaddrinfo(host, "", {socktype = posix.SOCK_STREAM})
	if not ips then return nil, string.format("dns: %s: %s", host, err) end
	
	-- TODO: which one do we wish to select?
	local dns = ips[1]
	dns.port = port -- update the port
	
	local fd = posix.socket(dns.family, dns.socktype, 0)
	if not fd then return nil, "failed to create socket" end
	
	local okay, err, e = posix.connect(fd, dns)
	if not okay then return nil, string.format("%s (%s) %d: %s", host, dns.addr, dns.port, err) end
	
	return socket.new_client(fd, dns.addr, dns.port)
end

function socket.new_client(fd, ip, port)
	local obj = {
		_fd = fd,
		_ip = ip,
		_port = port,
		_connected = true
	}
	
	set_nonblocking(fd)
	return setmetatable(obj, client)
end

-- listener funcs
function listener::accept(number timeout = -1)
	if not self._fd then return nil, "listener closed" end
	
	local nfd, addr = posix.accept(self._fd)
	if not nfd then return nil, addr end
	
	return socket.new_client(nfd, addr.addr, addr.port)
end

-- the port we're listening on, if socket.bind was passed 0, this will be assigned by the OS
function listener::port()
	return self._port
end

function listener::address()
	return self._address
end

-- stop listening
function listener::close()
	posix.close(self._fd)
	self._fd = nil
end

function listener::__gc()
	self:close()
end

-- client funcs

function client::type()
	return "tcp", "posix", socket.api_version
end

function client::ip()
	return self._ip
end

function client::port()
	return self._port
end

function client::connected()
	return self._connected
end


local format_lookup_all = {
	["a"] = true, ["*a"] = true
}
local format_lookup_line = {
	["l"] = true, ["*l"] = true
}

-- TODO: timeouts need to be implimented
function client::read(string format = "a", number limit = 0, number timeout = -1)
	local fd = self._fd
	
	local is_all = format_lookup_all[format]
	local is_line = format_lookup_line[format]
	
	if not is_all and not is_line then
		error("bad input format", 2)
	end
	
	local buffer = {}
	local fd = self._fd
	local recv = posix.recv
	
	if not fd then return nil, "connection closed" end
	
	if limit == 0 then
		if is_all then
			while true do
				local data, a, b = recv(fd, block_size)
				if not data then
					break
				elseif data:len() > 0 then
					table.insert(buffer, data)
				end
			end
		else -- a line
			while true do
				local data = recv(fd, 1)
				if not data then
					break
				elseif data == "\n" then
					break
				elseif data == "\r" then -- do nothing, this char is ignored
				elseif data:len() > 0 then
					table.insert(buffer, data)
				end
			end
		end
	else
		if is_all then
			while limit > 0 do
				local data, err = recv(fd, limit)
				if not data then
					break
				elseif data:len() > 0 then
					table.insert(buffer, data)
					limit = limit - data:len()
				end
			end
		else
			while limit > 0 do
				local data, err = recv(fd, 1)
				if not data then
					break
				elseif data:len() > 0 then
					if data == "\r" then
					elseif data == "\n" then
						break
					else
						table.insert(buffer, data)
					end
					limit = limit - data:len()
				end
			end
		end
	end
	
	return table.concat(buffer)
end

function client::write(string data, number from = 1, number to = -1)
	if not (from == 1 and to == -1) then
		data = data:sub(from, to)
	end
	local len = data:len()
	
	local sent, err, errcode = posix.send(self._fd, data)
	if not sent then
		self:close()
		return false, err
	end
	
	assert(sent == len)
	return true
end

function client::flush(number timeout = -1)
	return true
end

function client::close()
	if not self._fd then return end
	self._connected = false
	posix.close(self._fd)
	self._fd = nil
end

function client::__tostring()
	return "socket: " .. string.format("%s:%d (%d)", self:ip(), self:port(), self._fd or -1)
end

function client::__gc()
	self:close()
end

return socket
