
if not _VERSION:match("5%.1") then
	return
end

print("warning: running under 5.1 compatibility layer, please think about moving to a more recent Lua version.")

bit32 = require("bit")

function table.unpack(tbl, i, j)
	local n = tbl.n or #tbl
	i = i or 1
	j = math.min(j or n, n)
	
	local function unpack_it(k)
		if k >= j then
			return tbl[k]
		end
		return tbl[k], unpack_it(k + 1)
	end
	return unpack_it(i)
end

function table.pack(...)
	local t = {...}
	local max
	for k,v in pairs(t) do
		max = k
	end
	t.n = max
	return t
end
