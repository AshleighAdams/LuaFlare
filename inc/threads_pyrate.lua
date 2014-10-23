-- to take the options 'n stuff from caller, and imports
do
	local depth = 1
	while true do
		if not pcall(debug.getlocal, depth + (1 + 2), 1) then break end -- + 1 for next, itt, + 2 for pcall scopes
		depth = depth + 1
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

local wrap
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
	
	wrap = function(conn)
		local w = {}
		w.parent = conn
		
		return setmetatable(w, meta)
	end
end


-- https://github.com/vapourismo/pyrate
require("pyrate")

function main_loop()
	local server, err = socket.bind(host, port)
	assert(server, err)
	
	hook.safe_call("ReloadScripts") -- load all of our scritps, before forking anything!
	
	print("creating threads")
	assert(threads > 0)
	
	local created_threads = {}
	
	local function loop()
		while true do
			local client = server:accept()
			client:settimeout(5) -- 5 seconds until a timeout
			
			if not script.options["no-reload"] then
				hook.safe_call("ReloadScripts")
			end
			
			if https then
				client, err = ssl.wrap(client, params)
				assert(client, err)
				
				local suc, err = client:dohandshake()
				if not suc then print("ssl failed: ", err) end
			end
			
			client = wrap(client)
			
			if not handle_client(client) then
				client:close()
			end
		end
	end
	
	-- subtract one, because we're going to be one too
	for i = 1, threads - 1 do
		local t = thread.create()
		table.insert(created_threads, t)
		t:run(loop)
	end
	
	loop()
end
