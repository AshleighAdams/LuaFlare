local string_extension = {}

function string_extension.begins_with(haystack, needle) expects ("string", "string")
	return haystack:sub(1, needle:len()) == needle
end

function string_extension.ends_with(haystack, needle) expects ("string", "string")
	return needle == "" or haystack:sub(-needle:len()) == needle
end

string_extension.starts_with = string_extension.begins_with
string_extension.stops_with = string_extension.ends_with

function string_extension.replace(str, what, with) expects ("string", "string", "string")
	what = escape.pattern(what)
	with = with:gsub("%%", "%%%%") -- the 2nd arg of gsub only needs %'s to be escaped
	return str:gsub(what, with)
end

function string_extension.path(self) expects "string"
	return self:match("(.*/)") or ""
end

function string_extension.replace_last(str, what, with) expects ("string", "string", "string")
	local from, to, _from, _to = nil, nil
	local pos = 1
	local len = what:len()
	
	while true do
		_from, _to = string.find(str, what, pos, true)
		if _from == nil then break end
		pos = _to
		from = _from
		to = _to
	end
	
	local firstbit = str:sub(1, from - 1)
	local lastbit  = str:sub(to + 1)
	
	return firstbit .. with .. lastbit
end

function string_extension.trim(str) expects "string"
	return str:match("^%s*(.-)%s*$")
end

function string_extension.split(self, delimiter, options) expects("string", "string")
	delimiter = escape.pattern(delimiter)
	
	local result = {}
	local from  = 1
	local delim_from, delim_to = string.find(self, delimiter, from)
	while delim_from do
		local add = true
		local val = self:sub(from, delim_from - 1)
		
		if options and options.remove_empty and val:trim() == "" then
			add = false
		end
		
		if add then table.insert(result, val) end
		from  = delim_to + 1
		delim_from, delim_to = string.find(self, delimiter, from)
	end
	table.insert(result, string.sub(self, from ))
	return result
end

return string_extension
