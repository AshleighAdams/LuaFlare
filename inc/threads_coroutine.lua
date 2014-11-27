local threadpool = require("luaflare.threadpool")
local scheduler = require("luaflare.scheduler")
local hook = require("luaflare.hook")

-- detours shit to coroutinify it
routines = routines or {}

-- to take the options 'n stuff from caller, and imports
do
	local depth = 1
	while true do
		if not pcall(debug.getlocal, depth + (1 + 2), 1) then break end -- + 1 for next, itt, + 2 for pcall scopes
		depth = depth + 1
	end
	
	local version = tonumber(_VERSION:match("[%d%.]+"))
	local _ENV = _ENV
	
	if version <= 5.1 then
		-- simulate _ENV
		_ENV = setmetatable({}, {__newindex = function(self, k, v)
			getfenv()[k] = v
		end})
	end
	
	local i = 1
	while true do
		local name, val = debug.getlocal(depth, i)
		if name ~= nil then
			_ENV[name] = val
		else
			break
		end
		i = 1 + i
	end
end

do
	local meta = {}
	
	function meta.__index(tbl, k)
		if meta[k] then 
			return meta[k]
		end
		return function(tbl, ...)
			return tbl.parent[k](tbl.parent, ...)
		end
	end
	
	function meta:settimeout(t, m)
		rawset(self, "_timeout", t)
		return self.parent:settimeout(t, m)
	end
	
	-- needs to be coroutine-ified
	local chunksize = script.options["chunk-size"] or 512 -- 1KiB chunks
	function meta:send(data)
		self.parent:settimeout(0)
		
		while #data > 0 do
			local s, err, w = self.parent:send(data, 1, chunksize)
			if not s and err ~= "timeout" then
				print(string.format("connection error: %s", err))
				return
			end
			
			if s or w then
				data = data:sub((s or w) + 1, -1)
			end
			
			coroutine.yield()
		end
	end
	
	function meta:receive(pat, prefix)
		local to = rawget(self, "_timeout") or 5 --self.parent:gettimeout()
		
		if pat == "*l" then -- read a line
			local line, err
			local t = util.time() + to
			self.parent:settimeout(0)
			
			while true do
				if to ~= 0 and util.time() > t then
					return nil, "timeout"
				end
				
				line, err, part = self.parent:receive("*l")
				if line ~= nil then break end
				if err == "closed" then return nil, "closed" end
				coroutine.yield()
			end
			
			self.parent:settimeout(to)
			return line == nil and nil or (prefix or "") .. line, err
		elseif type(pat) == "number" then
			local ret = ""
			
			local t = util.time() + to
			self.parent:settimeout(0)
			
			local bytes = pat
			while bytes > 0 do
				local toget = math.min(bytes, 128) -- 128 byte chunks
				bytes = bytes - toget
				
				while true do
					if to ~= 0 and util.time() > t then
						return nil, "timeout"
					end
					
					data, err = self.parent:receive(toget)
					if err == "closed" then return nil, "closed" end
					if data == nil then
						coroutine.yield()
					else
						ret = ret .. data
						break -- fetch the next lot
					end
				end
			end
			
			self.parent:settimeout(to)

			return ret == nil and nil or (prefix or "") .. ret, err
		end
		
		--coroutine.yield()
		return self.parent:receive(pat, prefix)
	end
	


	function routines.wrap(conn)
		local w = {}
		w.parent = conn
		
		for k,v in pairs(meta) do
			
		end
		
		return setmetatable(w, meta)
	end
end


function main_loop()
	local server, err = socket.bind(host, port)
	assert(server, err)
	
	hook.safe_call("ReloadScripts") -- load all of our scritps, before forking anything!
	
	local function callback(client)
		client:settimeout(5) -- 5 seconds until a timeout
		
		if https then
			client, err = ssl.wrap(client, params)
			assert(client, err)
			
			local suc, err = client:dohandshake()
			if not suc then warn("ssl failed: ", err) end
		end
		
		client = routines.wrap(client)
		
		if not handle_client(client) then -- we can close it, otherwise, do not!
			client:close()
		end
	end
	
	local tp = threadpool.create(threads, callback)
	
	-- loaded now, call the hook
	hook.call("Loaded")
	
	while true do
		if tp:done() then
			-- we can block on accept() for this long...
			server:settimeout(scheduler.idletime())
		else
			server:settimeout(0)
		end
		
		--print("accept", tp:done(), scheduler.idletime())
		local client = server:accept()
		
		if not script.options["no-reload"] then
			hook.safe_call("ReloadScripts")
		end
		
		if client then tp:enqueue(client) end
		tp:step()
		scheduler.run()
	end
end
