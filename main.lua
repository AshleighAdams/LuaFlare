dofile("mimes.lua")

function main( con )
	con.log = function(text, ...)
		local comp = string.format(tostring(text), ...)
		
		Print(comp)
		
		local f = io.open("log.txt","a")
		f:write(comp)
		f:close()
	end

	con.write = function(text, ...)
		con.response = con.response .. string.format(tostring(text), ...)
	end
	
	log = con.log
	write = con.write
	
	log("%s %s\n", con.method, con.url)
	
	local extra = {}
	extra.ext = ""
	
	local urlpos = #con.url
	
	if string.sub(con.url, urlpos, urlpos) == '/' then
		con.url = con.url .. "index.lua"
	end
	
	while urlpos > 0 do -- Lets figgure out what the extension is
		local char = string.sub(con.url, urlpos, urlpos)
		
		if char == '/' then -- Is it a dir? well shit
			extra.ext = ""
			break
		elseif char == '.' then
			break
		end
		
		extra.ext = char .. extra.ext
		urlpos = urlpos - 1
	end
	
	if extra.ext == "lua" then
		local f, err = loadfile("www" .. con.url)
		if not f then
			log("Lua error: " .. err .. "\n")
		else
			local ne = {} -- the new enviroment, you can also isolate cirtain things here!, such as disallow io, require, ect..
			local _g = _G
			_g.con = con
			setmetatable(ne, {__index = _g})
			setfenv(f, ne)
			
			local status, ret = pcall(f)
			if not status then
				log("Lua error: %s\n", ret)
				write("Lua error: %s\n", ret)
			end
		end
	else
		con.errcode = nil
		con.response = nil
		con.response_file = "www" .. con.url
	end
	
	
	con.response_headers["Content-Type"] = MimeTypes[extra.ext] or "unknown"
	con.response_headers["Server"] = "luaserver"
	return con
end

