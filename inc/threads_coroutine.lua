local threadpool = require("threadpool")

-- detours shit to coroutinify it
routines = routines or {}

-- to take the options 'n stuff from caller, and imports
do
	local i = 1
	while true do
		local name, val = debug.getlocal(4, i)
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
	
	hook.Call("ReloadScripts") -- load all of our scritps, before forking anything!
	
	local function callback(client)
		client:settimeout(5) -- 5 seconds until a timeout
		
		if not script.options["no-reload"] then
			hook.Call("ReloadScripts")
		end
		
		if https then
			client, err = ssl.wrap(client, params)
			assert(client, err)
			
			local suc, err = client:dohandshake()
			if not suc then print("ssl failed: ", err) end
		end
		
		client = routines.wrap(client)
		
		if not handle_client(client) then -- we can close it, otherwise, do not!
			client:close()
		end
	end
	
	local tp = threadpool.create(threads, callback)
	
	while true do
		if tp:done() and scheduler.done() then
			server:settimeout(-1)
		else
			server:settimeout(0)
		end
		
		local client = server:accept()
		if client then tp:enqueue(client) end
		tp:step()
		scheduler.run()
		posix.nanosleep(0, 100)
	end
end