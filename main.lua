dofile("mimes.lua")

function main( con )
	local log = function(text, ...)
		local comp = string.format(tostring(text), ...)
		
		Print(comp)
		
		local f = io.open("log.txt","a")
		f:write(comp)
		f:close()
	end

	local write = function(text, ...)
		con.response = con.response .. string.format(tostring(text), ...)
	end
	
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
		dofile("www" .. con.url) -- If this fails, stack is increased by 1 D:
	else
		con.errcode = nil
		con.response = nil
		con.response_file = "www" .. con.url
	end
	
	
	con.response_headers["Content-Type"] = MimeTypes[extra.ext] or "unknown"
	con.response_headers["Server"] = "luaserver"
	return con
end

