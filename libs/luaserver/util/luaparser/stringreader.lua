local stringreader = {}
stringreader.meta = {}
stringreader.meta.__index = stringreader.meta
local meta = stringreader.meta

function meta:read(count) expects(meta)
	count = count or 1
	local from, to = self._position, self._position + (count - 1)
	self._position = self._position + count
	
	return self._data:sub(from,to)
end

function meta:peek(count) expects(meta)
	count = count or 1
	local from, to = self._position, self._position + (count - 1)
	return self._data:sub(from,to)
end

function meta:peekat(offset, count) expects(meta, "number")
	count = count or 1
	local from, to = self._position + offset, self._position + (count - 1)
	return self._data:sub(from,to)
end

function meta:peekmatch(pattern) expects(meta, "string")
	return self._data:sub(self._position):match("^" .. pattern) ~= nil
end

function meta:readmatch(pattern) expects(meta, "string")
	local ret = {self._data:sub(self._position):match("^(" .. pattern .. ")()")} -- empty capture = capture position
	if #ret == 0 then return end
	self._position = self._position + (ret[#ret] - 1)
	return table.unpack(ret)
end

function meta:eof() expects(meta)
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
