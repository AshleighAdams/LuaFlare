local unescape = {}

local url = require("socket.url")

function unescape.sql(string input)
	local ret = input
	
	ret = ret:gsub([[""]], [["]])
	ret = ret:gsub([['']], [[']])
	
	return ret
end

function unescape.url(string input)
	return url.unescape(input)
end

return unescape
