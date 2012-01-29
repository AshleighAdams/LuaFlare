<?lua

con.response_headers["Content-Type"] = "text/plain"

local action = GET.action

if not action then
	con.errcode = HTTP_INTERNALSERVERERROR
	return
end

if not SESSION.name then
	return
end

if action == "msg" then
	local stat, err = Lock(function()
		local tbl = table.load("chatshit.txt") or {}
		local msg = {
			when = GetCurrentTime(),
			msg = string.format("%s: %s", SESSION.name, EscapeHTML(GET.msg or "IM A FAG"))
		}
		table.insert(tbl, msg)
		table.save(tbl, "chatshit.txt")
		
		local f = io.open("chathist.txt", "a")
		if f then
			f:write(msg.msg .. "\n")
			f:close()
		end
	end)
end

if action == "getnewmsgs" then
	local session_lastcheck = SESSION.LastAPINewChat or GetCurrentTime()
	SESSION.LastAPINewChat = GetCurrentTime()
	
	Lock(function()
		local tbl = table.load("chatshit.txt") or {}
		local count = 0
		for k,v in pairs(tbl) do
			if v.when > session_lastcheck then
				writef(false, "%s\n", v.msg)
			end
			count = count + 1
		end
		if count > 40 then
			for k,v in pairs(tbl) do
				if (k+40)-count <= 0 then
					table.remove(tbl, k)
				end
			end
		end
		table.save(tbl, "chatshit.txt")
	end)
end

if action == "getallmsgs" then
	local session_lastcheck = SESSION.LastAPINewChat or GetCurrentTime()
	SESSION.LastAPINewChat = GetCurrentTime()
	
	Lock(function()
		local tbl = table.load("chatshit.txt") or {}
		for k,v in pairs(tbl) do
			writef(false, "%s\n", v.msg)
		end
		table.save(tbl, "chatshit.txt")
	end)
end

?>
