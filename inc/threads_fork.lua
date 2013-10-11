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

function main_loop()
	local server, err = socket.bind(host, port)
	assert(server, err)
	
	hook.Call("ReloadScripts") -- load all of our scritps, before forking anything!
	
	if threads > 0 then
		print("forking children") -- ... lol
		for i = 1, threads do
			if posix.fork() == 0 then break end -- so the forked processes don't fork again
		end
	end
	-- so we can spawn many processes, requires luasocket 3 
	--server:setoption("reuseport", true)
	
	while true do
		local client = server:accept()
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
		
		handle_client(client)
		client:close()
	end
end
