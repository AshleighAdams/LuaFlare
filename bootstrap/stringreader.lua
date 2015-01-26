local stringreader = {}
stringreader.meta = {}
stringreader.meta.__index = stringreader.meta
local meta = stringreader.meta

function meta:read(count)
	count = count or 1
	
	local op = self._position
	self._position = self._position + count
	
	return self._data:sub( op, op + (count - 1) )
end

function meta:peek(count)
	count = count or 1
	return self._data:sub( self._position, self._position + (count - 1) )
end

function meta:peekat(offset, count)
	count = count or 1
	return self._data:sub( self._position + offset, self._position + (count - 1) )
end

function meta:peekmatch(pattern)
	return self._data:match("^" .. pattern, self._position) ~= nil
end

function meta:readmatch(pattern)
	local ret = {self._data:match("^(" .. pattern .. ")()", self._position)} -- empty capture = capture position
	if #ret == 0 then return end
	self._position = (ret[#ret])
	return table.unpack(ret)
end

function meta:eof()
	return self._position > self._len
end

function stringreader.new(data) expects("string")
	local obj = {
		_data = data,
		_len = #data,
		_position = 1
	}
	return setmetatable(obj, meta)
end

return stringreader
