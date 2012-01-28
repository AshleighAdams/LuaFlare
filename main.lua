package.path = "./mods/?.lua;./mods/?;" .. package.path
package.cpath = "./mods/?.so;./mods/?.dll;" .. package.cpath

dofile("includes/mimes.lua")
dofile("includes/statuscodes.lua")
dofile("includes/util.lua")
dofile("includes/savetabletofile.lua")

function file_exists(name)
   local f=io.open(name,"r")
   if f~=nil then io.close(f) return true else return false end
end

function loadfile_parselua(name)
	local f = io.open(name, r)
	if not f then
		return false, "Can't open file \"" .. name .. "\""
	end
	
	local lua_html = f:read("*a")
	io.close(f)
	
	local lua, err = ParseLuaString(lua_html)
	
	if not lua then
		return false, name .. ":EOF: " .. err
	end
	--Print(lua .. "\n")
	
	return loadstring(lua, name)
end

function main( con )
	con.log = function(text, ...)		
		local comp = string.format(tostring(text), ...)
		comp = string.format("[%s] %s", os.date(), comp)
		Lock(function()
			Print(comp)
			
			local f = io.open("log.txt","a")
			if f then
				f:write(comp)
				f:close()
			end
		end)
	end

	con.writef = function(escape, text, ...)
		if (type(escape) == type(false) and escape) or type(escape) ~= type(false) then
			if type(escape) ~= type(false) then
				con.write(string.format(escape, text, ...))
			else
				con.write(escape, string.format(escape, text, ...))
			end
		else
			if type(escape) ~= type(false) then
				con.write(escape, string.format(escape, text, ...))
			else
				con.write(escape, string.format(text, ...))
			end
		end
	end
	
	con.write = function(escape, text)
		if (type(escape) == type(false) and escape) or type(escape) ~= type(false) then
			if type(escape) ~= type(false) then
				con.response = con.response .. EscapeHTML(escape)
			else
				con.response = con.response .. EscapeHTML(text)
			end
		else
			if type(escape) ~= type(false) then
				con.response = con.response .. escape
			else
				con.response = con.response .. text
			end
		end
	end
	
	log = con.log
	write = con.writef
	
	log("%s %s %s\n", con.ip, con.method, con.url)
	
	Lock(function()
		LoadSession(con)
	end)
	
	local extra = {}
	extra.ext = ""
	
	local server = con.HEADER.Host or "default"
	server = string.gsub(server, [[\.\.]], "") -- Remove any ..'s to stop directory transversing
	server = string.match(server, "[A-z0-9\\.]+") -- Remove the port, if present
	server = "www/" .. server
	
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
		if err then
			log("Lua error: %s\n", err)
			write("Lua error.  Check log for details\n")
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
			scriptenv.SESSION = con.SESSION
			scriptenv.write = con.write
			scriptenv.writef = con.writef
			scriptenv.log = con.log
			
			scriptenv.loadfile = nil
			scriptenv.dofile = nil
			
			scriptenv.include = function(file)
				local incf,err = loadfile_parselua(server .. "/" .. file)
				if err then
					log("%s\n", err)
					write("Lua error.  See log for details\n")
					con.errcode = HTTP_INTERNALSERVERERROR
				else
					setfenv(incf, ne)
					local status, ret = pcall(incf)
					
					if not status then
						log("Lua error: %s\n", ret)
						write("Lua error.  Check log for details")
						con.errcode = HTTP_INTERNALSERVERERROR
					end
				end
			end
			
			setmetatable(ne, {__index = scriptenv})
			setfenv(f, ne)
			
			local status, ret = pcall(f)
			if not status then
				log("Lua error: %s\n", ret)
				write("Lua error.  Check log for details\n")
				con.errcode = HTTP_INTERNALSERVERERROR
			end
		end
	else
		con.errcode = nil
		con.response = nil
		con.response_file = server .. con.url
	end
	
	Lock(function()
		HandelSession(con)
	end)
	
	con.response_headers["Content-Type"] = MimeTypes[extra.ext] or "unknown"
	con.response_headers["Server"] = "luaserver"
	
	return con
end

local sessionlen = 100 -- 100 in length should be sufficient

function LoadSession(con)
	con.SESSION = {}
	
	if not con.COOKIE.luasession or string.find(con.COOKIE.luasession, "deleted", 1, true) then
		con.SesWasNil = true
		return
	end
	
	local sessid = ""
	for i = 1, sessionlen do
		local b = string.byte(con.COOKIE.luasession, i) or 0
		if 		(b >= 48 and b < 48+10) or
				(b >= 65 and b < 65+26) or
				(b >= 97 and b < 97+26) then
			sessid = sessid .. string.char(b)
		else
			sessid = nil
			break
		end
	end
	
	if not sessid then
		con.log("Warning: malformed luasession cookie: %s\n", con.COOKIE.luasession)
		con.set_cookies.luasession = "deleted; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT"
		con.COOKIE.luasession = nil
		con.SesWasNil = true
		return
	end
		
	con.COOKIE.luasession = sessid
	con.SESSION = table.load("sessions/" .. sessid .. ".txt")
	
	if not con.SESSION then
		con.set_cookies.luasession = "deleted; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT"
		con.COOKIE.luasession = nil
		con.SesWasNil = true
		con.SESSION = {}
	end
	
	-- The func below returns an empty table with a metatable that points to the old one
	--con.SESSION
end

function HandelSession(con)	
	if con.COOKIE.luasession and not con.SESSION then
		os.remove("sessions/" .. con.COOKIE.luasession .. ".txt")
		con.set_cookies.luasession = "deleted; path=/; expires=Thu, 01 Jan 1970 00:00:00 GMT"
	elseif con.SESSION and con.SesWasNil and table.Count(con.SESSION) > 0 then -- Create a session
		con.SESSION.LastSeen = os.time()
		
		local sessionid = GenerateSessionID(sessionlen)
		local f = io.open("sessions/" .. sessionid .. ".txt", "w")
		if f then
			f:close()
			table.save(con.SESSION, "sessions/" .. sessionid .. ".txt")
			log("Created session \"%s\" for %s\n", sessionid, con.ip)
			con.set_cookies.luasession = sessionid .. "; path=/;"
		else
			log("Failed to create session \"%s\" for %s\n", sessionid, con.ip)
		end
	elseif con.SESSION and con.COOKIE.luasession and table.Count(con.SESSION) > 0 then
		con.SESSION.LastSeen = os.time()
		table.save(con.SESSION, "sessions/" .. con.COOKIE.luasession .. ".txt")
	end
end
