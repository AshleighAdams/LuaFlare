
function write(con, text)
	con.response = con.response .. tostring(text)
end

function main( con )
	Print("File requested: " .. con.url .. "<br/>")
	write(con, "Hello, sorry Dave, I can't serve " .. con.url .. " to you.<br/>")
	write(con, "MTHD: " .. con.method .. "<br/>")
	write(con, "VERS: " .. con.version .. "<br/>")
	
	write(con, "<br/>Headers:")
	for k,v in pairs(con.HEADER) do
		write(con, "<br/>" .. k .. ": " .. v)
	end
	
	write(con, "<br/><br/>GET:")
	for k,v in pairs(con.GET) do
		write(con, "<br/>" .. k .. ": " .. v)
	end
	
	write(con, "<br/><br/>POST:")
	for k,v in pairs(con.POST) do
		write(con, "<br/>" .. k .. ": " .. v)
	end
	
	con.errcode = 418
	con.response_headers = {}
	con.response_headers["Content-Type"] = "text/html"
	con.response_headers["Server"] = "luaserver"
	return con
end
