
function main( con )
	Print("File requested: " .. con.url .. "\n")
	con.response = "Hello, sorry Dave, I can't serve " .. con.url .. " to you.\n"
	con.response = con.response .. "MTHD: " .. con.method .. "\n"
	con.response = con.response .. "VERS: " .. con.version .. "\n"
	
	return con
end
