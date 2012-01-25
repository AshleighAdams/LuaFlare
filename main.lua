dofile("mimes.lua")

function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

function loadfile_parselua(name)
	local f = io.open(name, r)
	if not f then
		io.close(f)
		return false, "Cannot open " .. name
	end
	
	local lua = f:read("*a")
	io.close(f)
	
	lua = ParseLuaString(lua)
	--Print(lua .. "\n")
	
	return loadstring(lua, name)
end

function main( con )
	con.log = function(text, ...)
		local comp = string.format(tostring(text), ...)
		
		Print(comp)
		
		local f = io.open("log.txt","a")
		f:write(comp)
		f:close()
	end

	con.writef = function(text, ...)
		con.response = con.response .. string.format(tostring(text), ...)
	end
	
	con.write = function(text)
		con.response = con.response .. tostring(text)
	end
	
	log = con.log
	write = con.writef
	
	log("%s %s\n", con.method, con.url)
	
	local extra = {}
	extra.ext = ""
	
	local server = con.HEADER.Host or "www"
	server = string.match(server, "[A-z0-9\.]+") -- Remove the port, if present
	
	local urlpos = #con.url
	
	if string.sub(con.url, urlpos, urlpos) == '/' then
		con.url = con.url .. "index.lua"
	end
	
	if not file_exists(server .. con.url) then
		con.url = "/404.lua"
	end
	
	local urlpos = #con.url -- Update this
	
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
		local f, err = loadfile_parselua(server .. con.url)
		if not f then
			log("Lua error: " .. err .. "\n")
		else
			local ne = {} -- the new enviroment, you can also isolate cirtain things here!, such as disallow io, require, ect..
			local scriptenv = {}
			
			for k,v in pairs(_G) do
				scriptenv[k] = v
			end
			
			scriptenv.con = con
			scriptenv.GET = con.GET
			scriptenv.POST = con.POST
			scriptenv.COOKIE = con.COOKIE
			scriptenv.write = con.write
			scriptenv.writef = con.writef
			scriptenv.log = con.log
			
			scriptenv.loadfile = nil
			scriptenv.dofile = nil
			
			scriptenv.include = function(file)
				local incf,err = loadfile_parselua(server .. "/" .. file)
				if err then
					Print(err .. "\n")
				else
					setfenv(incf, ne)
					incf()
				end
			end
			
			setmetatable(ne, {__index = scriptenv})
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
		con.response_file = server .. con.url
	end
	
	
	con.response_headers["Content-Type"] = MimeTypes[extra.ext] or "unknown"
	con.response_headers["Server"] = "luaserver"
	return con
end

