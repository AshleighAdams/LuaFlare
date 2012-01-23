
function write(con, text)
	con.response = con.response .. tostring(text)
end

function main( con )
	Print("File requested: " .. con.url .. "\n")
	write(con, "Hello, sorry Dave, I can't serve " .. con.url .. " to you.\n")
	write(con, "MTHD: " .. con.method .. "\n")
	write(con, "VERS: " .. con.version .. "\n")
	
	write(con, "\nHeaders:")
	for k,v in pairs(con.HEADER) do
		write(con, "\n" .. k .. ": " .. v)
	end
	
	write(con, "\n\nGET:")
	for k,v in pairs(con.GET) do
		write(con, "\n" .. k .. ": " .. v)
	end
	
	write(con, "\n\nPOST:")
	for k,v in pairs(con.POST) do
		write(con, "\n" .. k .. ": " .. v)
	end
	
	return con
end
