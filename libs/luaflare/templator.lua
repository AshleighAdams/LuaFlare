local templator = {}
local generated = {}

templator.generated = generated
generated.__index = generated

local escape = require("luaflare.util.escape")

templator.custom_escapers = {}

-- does nothing
templator.custom_escapers.none = function(string input)
	return input
end

function templator.generate(string html)
	local buffer = {}
	local markers = {}
	local position = 1
	
	html:gsub("[^\\]()%$%((.-)%)()", function(pos, args, endpos)
		local sect = html:sub(position, pos - 1)
		position = endpos
		
		args = args:split(",")
		
		local name = args[1]:trim()
		local escaper = (args[2] or "html"):trim()
		local escape_func = templator.custom_escapers[escaper] or escape[escaper] -- try our custom ones first
		
		local level = 2 + 2 -- 2 = generate's parent, +2 for gsub (c side, and lua side)
		if not name then
			error("invalid input: name missing", level)
		end
		if not escape_func then
			error("invalid input: unknown escaper: " .. escaper, level)
		end
		
		local indents
		
		sect:gsub("\n(%s+)$", function(ident)
			indents = ident
		end)
		
		sect = sect:gsub("\\%$%(", "$(")
		
		table.insert(buffer, sect)
		table.insert(buffer, "")
		table.insert(markers, {
			index = #buffer,
			name = name,
			escape = escape_func,
			indents = indents
		})
	end)
	
	local sect = html:sub(position, -1)
	sect = sect:gsub("\\%$%(", "$(")
	table.insert(buffer, sect) -- add the rest to the buffer
	
	return setmetatable({
		buffer = buffer,
		markers = markers
	}, generated)
end

function generated::__call(table values)
	local buff = self.buffer
	for k,marker in ipairs(self.markers) do
		local str = values[marker.name]
		
		if not str then
			error("values: could not find value " .. marker.name)
		end
		
		str = marker.escape(tostring(str))
		
		if marker.indents then
			str = str:gsub("\n", "\n"..marker.indents)
		end
		
		buff[marker.index] = str
	end
	
	return table.concat(buff)
end

return templator
