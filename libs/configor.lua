local configor = {}

local function inrange(val, ...)
	local args = {...}
	
	for i = 1, #args do
		local min, max = args[i][1], args[i][2]
		if not (val >= from and val <= to) then
			return false
		end
	end
	return true
end
-- returns end position, string
local function parse_hex(str, pos, len)
	if pos + 1 < len then
		return nil, "not enough room to parse hex literal"
	end
	
	local a = str:sub(pos, pos):lower()
	local b = str:sub(pos + 1, pos + 1):lower()
	
	if not inrange(a, {"a", "f"}, {"0", "9"}) or not inrange(a, {"a", "f"}, {"0", "9"}) then
		return nil, "invalid hex digit: 0x" .. a .. b
	end
	
	return 2, tonumber(a .. b, 16)
end

local literals = {
	n = "\n",
	r = "\r",
	t = "\t",
	v = "\v",
	b = "\b",
	a = "\a",
	f = "\f",
	x = parse_hex
}
local function parse_quotes(str, start)
	local literal = false
	local len = #str
	local ret = ""
	start = start + 1 -- remove the first quote
	
	local i = start
	while i <= len do
		local char = str:sub(i, i)
		
		if literal then
			local read, lit = 1, literals[char]
			
			if type(lit) == "function" then
				read, lit = lit(str, i, len)
				if read == nil then
					return nil, "failed to parse literal: " .. lit
				end
			end
			
			ret = ret .. lit
			i = i + (read - 1) -- increase the chars we've read
			literal = false
		else
			if char == '"' then
				return i, ret
			elseif char == '\\' then
				literal = true
			elseif char == "\n" or char == "\r" then
				return nil, "newline in string value"
			else
				ret = ret .. char
			end
		end
		i = i + 1
	end
	
	return nil, "" -- whoops, we got to the end, and no quote found...
end

-- Turn the string into some simple tokens, such as
-- string "abc"
-- string "def"
-- operator "{"
-- string "123"
-- newline
-- string "345"
-- operator "}"
---
-- which is equilivant to:
--"abc" "def"
--{
--	"123"
--	"345"
--}
local function tokenize(str)
	local pos, char = 1, nil
	local ret = {}
	local cur_line = 1
	local len = #str
	
	while pos <= len do
		char = str:sub(pos, pos)
		
		if char == "\n" then
			table.insert(ret, {token="newline", line=cur_line})
			cur_line = cur_line + 1
		elseif char == '"' then
			local endpos, val = parse_quotes(str, pos)
			if endpos == nil then
				return nil, string.format("error parsing string literal: %s (started line %i)", val, cur_line)
			end
			pos = endpos
			table.insert(ret, {token="string", value=val, line=cur_line})
		elseif char == ' ' or char == '\t' or char == '\r' then -- do nothing with them
		else -- it must be an operator
			table.insert(ret, {token="operator", operator=char, line=cur_line})
		end
		
		pos = pos + 1
	end
	
	return ret
end

function configor.loadstring(str)
	local tokens, err = tokenize(str)
	print(err)
	PrintTable(tokens)
end

function configor.loadfile(path)
	local file, err =  io.open(path, "r")
	if not file then return nil, string.format("could not open file (%s)", err) end
	
	local contents = file:read("*a")
	return configor.loadstring(contents)
end

return configor