local unescape = {}

function unescape.sql(string input)
	local ret = input
	
	ret = ret:gsub([[""]], [["]])
	ret = ret:gsub([['']], [[']])
	
	return ret
end

return unescape
