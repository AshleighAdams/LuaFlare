
local socket = {}
socket.backend = "luasocket"
socket.api_version = "0.2"

local luasocket = require("socket")

socket.client = {}
socket.listener = {}

local client, listener = socket.client, socket.listener
client.__index = client
listener.__index = listener

function socket.listen(string address = "*", number port = 0)
	local tcp = luasocket.tcp()
	
	local suc, err = tcp:bind(address, port)
	if not suc then
		return nil, "failed to bind: " .. err
	end
	
	suc, err = tcp:listen()
	if not suc then
		return nil, "failed to listen: " .. err
	end
	
	local obj = {
		_tcp = tcp,
		_port = port,
		_address = address
	}
	
	return setmetatable(obj, listener)
end

function socket.connect(string host, number port)
	local tcp = luasocket.tcp()
	local suc, err = tcp:connect(host, port)
	
	if not suc then
		return nil, err
	end
	
	return socket.new_client(tcp)
end

function socket.new_client(tcp)
	local ip, port = tcp:getpeername():match("(.+):(.+)")
	
	local obj = {
		_tcp = tcp,
		_ip = ip,
		_port = port,
		_connected = true
	}
	
	return setmetatable(obj, client)
end

-- listener funcs
function listener::accept(number timeout = -1)
	self._tcp:settimeout(timeout)
	
	local tcp, err = self._tcp:accept()
	if not tcp then
		return nil, err
	end
	
	return socket.new_client(tcp)
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
	self._tcp:close()
end

-- client funcs

function client::type()
	return "tcp", "luasocket", socket.api_version
end

function client::ip()
	return self._ip
end

function client::port()
	return self._port
end

function client::connected()
	-- luasocket can't tell if a connection is connected,
	-- only by failing a send/receive can we tell, so return the last known state
	return self._connected
end


local format_lookup_all = {
	["a"] = true, ["*a"] = true
}
local format_lookup_line = {
	["l"] = true, ["*l"] = true
}

function client::read(string format = "a", number limit = 0, number timeout = -1)
	local tcp = self._tcp
	
	tcp:settimeout(timeout)
	
	local is_all = format_lookup_all[format]
	local is_line = format_lookup_line[format]
	
	if not is_all and not is_line then
		error("bad input format", 2)
	end
	
	if limit == 0 then
		format = is_all and "*a" or "*l"
		local r, e, p = tcp:receive(format)
			if not r and e == "closed" then -- update our connection state
				self._connected = false
			end
		return r, e, p
	else -- want max number of bytes, *a can do this, but *l needs to be implimented
		if is_all then
			local r, e, p = tcp:receive(limit)
				if not r and e == "closed" then
					self._connected = false
				end
			return r, e, p
		else
			local buff, byte, err = {}
			for i = 1, limit do
				byte, err = tcp:receive(1)
				if not byte then
					if err == "closed" then
						self._connected = false
					end
					return nil, err, table.concat(buff)
				elseif byte == "\n" then
					break
				elseif byte == "\r" then
					-- ignore it
				else
					buff[i] = byte
				end
			end
			
			return table.concat(buff)
		end
	end
end

function client::write(string data, number from = 1, number to = -1)
	self._tcp:settimeout(timeout)
	return self._tcp:send(data, from, to)
end

function client::flush(number timeout = -1)
	return true
end

function client::close()
	self._connected = false
	self._tcp:close()
end

function client::__tostring()
	return "socket: " .. tostring(self._tcp)
end

function client::__gc()
	self:close()
	self._tcp = nil
end

return socket
