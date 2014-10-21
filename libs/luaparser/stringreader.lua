local stringreader = {}
stringreader.meta = {}
stringreader.meta.__index = stringreader.meta
local meta = stringreader.meta

function meta::read(count)
	count = count or 1
	local from, to = self._position, self._position + (count - 1)
	self._position = self._position + count
	
	return self._data:sub(from,to)
end

function meta::peek(count)
	count = count or 1
	local from, to = self._position, self._position + (count - 1)
	return self._data:sub(from,to)
end

function meta::peekat(number offset, count)
	count = count or 1
	local from, to = self._position + offset, self._position + (count - 1)
	return self._data:sub(from,to)
end

function meta::peekmatch(string pattern)
	return self._data:sub(self._position):match("^" .. pattern) ~= nil
end

function meta::readmatch(string pattern)
	local ret = {self._data:sub(self._position):match("^(" .. pattern .. ")()")} -- empty capture = capture position
	if #ret == 0 then return end
	self._position = self._position + (ret[#ret] - 1)
	return table.unpack(ret)
end

function meta::eof()
	return self._position > self._len
end

function stringreader.new(string data)
	local obj = {
		_data = data,
		_len = #data,
		_position = 1
	}
	return setmetatable(obj, meta)
end

return stringreader
