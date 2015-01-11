local G = {}

-- table globals
function G.print_table(tbl, done, depth) expects "table"
	
	done = done or {}
	depth = depth or 0
	if done[tbl] then return end
	done[tbl] = true
	
	local tabs = string.rep("\t", depth)
	
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			print(tabs .. tostring(k) .. ":")
			print_table(v, done, depth + 1)
		else
			print(tabs .. tostring(k) .. " = " .. tostring(v))
		end
	end
end
G.PrintTable = function(...)
	warn("PrintTable renamed to print_table")
	return print_table(...)
end

return G
