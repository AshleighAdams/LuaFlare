
function main_old( con )
	
	local write = function(text, ...)
		con.response = con.response .. string.format(tostring(text), ...)
	end

	Print(con.method .. " " .. con.url .. "\n")
	
	write("Hello, sorry Dave, I can't serve \"%s\" to you.<br/>", con.url)
	
	write("<br/>Headers:")
	for k,v in pairs(con.HEADER) do
		write("<br/>%s = %s", k, v)
	end
	
	write("<br/><br/>GET:")
	for k,v in pairs(con.GET) do
		write("<br/>%s = %s", k, v)
	end
	
	write("<br/><br/>POST:")
	for k,v in pairs(con.POST) do
		write("<br/>%s = %s", k, v)
	end
	
	con.response_headers["Content-Type"] = "text/html"
	con.response_headers["Server"] = "luaserver"
	return con
end

function main( con )
	con.response = nil -- Tell it to check response_file instead, just saves CPU
	con.errcode = nil -- So it's not overidden (the response file result)
	
	con.response_file = "testimg.png"
	
	con.response_headers["Content-Type"] = "image/png"
	
	return con
end
