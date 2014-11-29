
local hosts = require("luaflare.hosts")
local scheduler = require("luaflare.scheduler")
local sha1 = require("sha1")
local bit = require("bit")
local base64 = require("base64")

local websocket = {}
websocket.TEXT = 129
websocket.registered = {}

local function send_message(client, payload)
	local len = payload:len()
	local header
	local mode = bit.lshift(1, 7) + 1 -- +1 for TEXT, +2 for BINARY  -- websocket.TEXT
	
	if len < 126 then
		header = {
			mode,
			len
		}
	elseif len <= 0xffff then
		header = {
			mode,
			126,
			bit.band( bit.rshift(len, 8) , 255),
			bit.band(            len     , 255),
		}
	else
		header = {
			mode,
			127,
			bit.band( bit.rshift(len, 56) , 255),
			bit.band( bit.rshift(len, 48) , 255),
			bit.band( bit.rshift(len, 40) , 255),
			bit.band( bit.rshift(len, 32) , 255),
			bit.band( bit.rshift(len, 24) , 255),
			bit.band( bit.rshift(len, 16) , 255),
			bit.band( bit.rshift(len,  8) , 255),
			bit.band(            len      , 255),
		}
	end
	
	header = string.char(unpack(header))
	client:send(header .. payload)
	-- this little shit below, IT TOOK ME THREE FUCKING HOURS TO FIND THIS BUG
	-- (that string.format is a binding to the C function, which does NOT like null-bytes!)
	--string.format("%s%s", header, payload))
end

local function read_message(client)
	local function receive(count)
		local ret, err = client:receive(count)
		if ret == nil then
			error(err)
		end
		return ret
	end
	
	local opcode = string.byte(receive(1))
	local typ = bit.band(opcode, 15)
	
	if typ == 1 or typ == 2 then -- text or binary
	elseif typ == 8 then -- disconnect?
		error("disconnected")
	else
		assert(false, string.format("unknown opcode %s", typ))
	end
	
	local b1 = string.byte(receive(1))
	local enc = bit.band(b1, 128) == 128
	local len = 0
	
	if bit.band(b1, 127) < 126 then -- 1 byte
		len  = bit.band(b1, 127)
	elseif bit.band(b1, 127) == 126 then -- 2 bytes
		len = 0
			+ bit.lshift(string.byte(receive(1)), 8)
			+            string.byte(receive(1))
	else -- 8 bytes
		len = 0
			+ bit.lshift(string.byte(receive(1)), 56)
			+ bit.lshift(string.byte(receive(1)), 48)
			+ bit.lshift(string.byte(receive(1)), 40)
			+ bit.lshift(string.byte(receive(1)), 32)
			+ bit.lshift(string.byte(receive(1)), 24)
			+ bit.lshift(string.byte(receive(1)), 16)
			+ bit.lshift(string.byte(receive(1)),  8)
			+            string.byte(receive(1))
	end
	
	local payload
	
	if enc then -- need to XOR 
		local mask = { receive(4):byte(1, 4) }
		local bytes = { receive(len):byte(1, len) }
		
		for i = 1, len do
			bytes[i] = bit.bxor(bytes[i], mask[((i - 1) % 4) + 1])
		end
		
		payload = string.char(unpack(bytes))
	else -- no need to XOR
		payload = receive(len)
	end
	
	return payload
end

local function Upgrade_websocket(request, response)
	local client = request:client()
	
	local key      = request:headers()["Sec-WebSocket-Key"]
	local protocol = request:headers()["Sec-WebSocket-Protocol"] or ""
	local version  = request:headers()["Sec-WebSocket-Version"]
	
	if not key or not protocol or not version then
		print("Upgrade [websocket] failed:", key, protocol, version)
		response:halt(400, "The header Sec-Websocket-Key, or Sec-WebSocket-Version was not set!") -- bad request
		response:send()
		return
	end
	
	local path_tbl = websocket.registered[request:url()]
	if not path_tbl then
		print("WebSocket at path not found")
		response:halt(404, string.format("A web socket is not listening at %s", request:url()))
		response:send()
		return
	end
	
	local proto = path_tbl[protocol]
	if not proto then
		print("WebSocket proto not found")
		
		response:halt(404, 
			string.format("A web socket is not listening at %s with the protocol %s",
				request:url(),
				protocol
			)
		)
		response:send()
		return
	end
	
	-- okay, there's a registered client, let's authenticate
	
	local hash = base64.encode(sha1.binary(key .. "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
	
	print(string.format("websocket: %s: generated the hash %s from key %s", protocol, hash, key))
	
	request:set_upgraded() -- report that the connection has been upgraded
	response:clear_headers()
	response:set_status(101)
	response:set_header("Upgrade", "websocket")
	response:set_header("Connection", "Upgrade")
	response:set_header("Sec-WebSocket-Accept", hash)
	response:set_header("Sec-WebSocket-Protocol", protocol)
	response:send()
	
	-- client now should be a websocket protocol
	client:settimeout(0)
	client.peer = request:peer()
	client.request = request -- so we can take cookies and stuffs
	
	proto.newclient(client)
	
	--	send_message(client, "hello")
	--	print(string.format("websocket: message: %s", read_message(client)))
	--	send_message(client, "world")
	--	print(string.format("websocket: message: %s", read_message(client)))
		--client:send("hello\n")
	--end
end

hosts.upgrades["websocket"] = Upgrade_websocket

local meta = {}
meta._metatbl = {__index = meta}

function websocket.register(string path, string protocol = "", _callbacks)
	websocket.registered[path] = websocket.registered[path] or {}
	websocket.registered[path][protocol] = {} -- TODO:
	
	if _callbacks ~= nil then
		warn("websockets API changed, callbacks are added to the returned object directly now")
		
		local callbacks = _callbacks
		local ret = websocket.register(path, protocol)
		
		for k,v in pairs(callbacks) do
			local name = k:match("on(.+)")
			local func = v
			if name then
				ret["on_" .. name] = function(self, ...)
					func(...)
				end
			end
		end
		
		return ret
	end
	
	print(string.format("websocket: registering %s at %s", protocol, path))
	
	local obj = websocket.registered[path][protocol]
	obj._path = path
	obj._protocol = protocol
	obj._clients = {}
	obj._client_threads = {}
	
	obj.newclient = function(client)
		--error("not implimented", 2)
		
		-- create a thread for them
		local thread = function()
			-- call the onconnect callback
			if obj.on_connect then
				obj:on_connect(client)
			end
			
			while true do
				local suc, msg = pcall(read_message, client)
				if not suc then break end -- client disconnected
				
				if obj.on_message then
					obj:on_message(client, msg)
				end
			end
			
			if obj.on_disconnect then
				obj:on_disconnect(client)
			end
			table.remove_value(obj._clients, client) -- nil-ify them
			--obj._client_threads[client] = nil
		end
		
		scheduler.newtask(string.format("ws://%s%s (%s)", client.peer, path, protocol), thread)
		table.insert(obj._clients, client)
		
		--local co = coroutine.create(thread)
		--obj._client_threads[client] = co
	end
	
	return setmetatable(obj, meta._metatbl)
end

function meta:send(message, client) expects(meta._meta, "string")
	if client == nil then --send to all the clients
		for k,cl in pairs(self._clients) do
			send_message(cl, message)
		end
	else
		send_message(client, message)
	end
end

function meta:wait()
	-- halts execution until a client connects
	while #self._clients == 0 do
		coroutine.yield(0.25)
	end
end

return websocket
