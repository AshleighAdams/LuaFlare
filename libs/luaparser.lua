local parser = {}
local stringreader = require("luaparser.stringreader")

parser.keywords = {
	["and"] = true,        ["break"] = true,
	["do"] = true,         ["else"] = true,
	["elseif"] = true,     ["end"] = true,
	["for"] = true,        ["function"] = true,
	["goto"] = true,       ["if"] = true,
	["in"] = true,         ["local"] = true,
	["not"] = true,        ["or"] = true,
	["repeat"] = true,     ["return"] = true,
	["then"] = true,       ["until"] = true,
	["while"] = true
}

parser.tokenchars_joinable = {
	["+"] = true, ["-"] = true, ["*"] = true, ["/"] = true, ["%"] = true,
	["^"] = true, ["#"] = true, ["="] = true, ["~"] = true, ["<"] = true,
	[">"] = true, ["."] = true, ["::"] = true
}
parser.tokenchars_unjoinable = {
	["("] = true, [")"] = true, ["["] = true, ["]"] = true, ["{"] = true,
	["}"] = true, [";"] = true, [","] = true
}

-- things that modify the scope
parser.scope_ins = {
	["do"] = true, ["then"] = true, ["repeat"] = true
}
parser.scope_both = {
	["else"] = true
}
parser.scope_out = {
	["end"] = true, ["elseif"] = true, ["until"] = true
}

parser.escapers = {
	["x(..)"] = function(str)
		return string.char(tonumber(str, 16))
	end,
	["0(%d%d?%d?)"] = function(str)
		return string.char(tonumber(str)) -- is it base 10?
	end,
	["a"] = function() return "\a" end,
	["b"] = function() return "\b" end,
	["f"] = function() return "\f" end,
	["n"] = function() return "\n" end,
	["r"] = function() return "\r" end,
	["t"] = function() return "\t" end,
	["v"] = function() return "\v" end,
	["\\"] = function() return "\\" end,
	["\""] = function() return "\"" end,
	["\'"] = function() return "\'" end,
	["%["] = function() return "[" end,
	["%]"] = function() return "]" end
}

function parser.tokenize(string code)
	local tokens = {}
	local reader = stringreader.new(code)
	
	local _line = 1
	local _startpos = 1
	
	local function add_token(tkn) -- fills some special info in too
		tkn.line = _line
		tkn.range = {_startpos, reader._position - 1}
		tkn.chunk = code:sub(tkn.range[1], tkn.range[2])
		table.insert(tokens, tkn)
		
		if tkn.type == "unknown" then
			local ptkn = tokens[#tokens - 1] or error()
			error(string.format("failed to tokenize at line %d (char: %q, previous chunk: %s)", tkn.line, tkn.value, ptkn.chunk), 3)
		elseif tkn.type == "newline" then
			_line = _line + 1
		end
		_startpos = reader._position
	end
	
	while not reader:eof() do
		local mode = reader:peek()
		
		if reader:peek(2) == "--" then
			
			reader:read(2) --
			local block = reader:peek() == "["
			local value
			
			if not block then
				value = reader:readmatch("(.-)\r?\n")
			else
				reader:read()
				local equals = ""
				if reader:peek() == "=" then
					equals = reader:readmatch("=+")
				end
				
				local inside = reader:readmatch(".-%]" .. equals .. "%]")
				value = inside:sub(1,-4)
				block = {equals = equals}
			end
			
			add_token({
				type = "comment",
				block = block,
				value = value
			})
			
		elseif mode == '"' or mode == "'" or reader:peekmatch("%[=*%[") then
			
			local endchar = reader:read()
			local block = mode == "["
			local value
			
			if block then
				reader:read()
				local equals = ""
				if reader:peek() == "=" then
					equals = reader:readmatch("=+")
				end
				
				local inside = reader:readmatch(".-%]" .. equals .. "%]")
				value = inside:sub(1,-4)
				block = {equals = equals}
			else
				local buff = {}
				while not reader:eof() do
					local char = reader:read()
					if char == endchar then break end
					
					if char == "\\" then
						-- \Z == readmatch(".-\r?\n")
						local got = false
						for pattern,func in pairs(parser.escapers) do
							if reader:peekmatch(pattern) then
								local read = reader:readmatch(pattern)
								table.insert(buff, func(read:match(pattern)))
								got = true
								break
							end
						end
						
						if not got then error("unknown escape sequence " .. reader:peek()) end
						
					else
						table.insert(buff, char)
					end
				end
				value = table.concat(buff)
			end
			
			add_token({
				type = "string",
				block = block,
				value = value
			})
			
		elseif parser.tokenchars_joinable[mode] then
			
			local op = {reader:read()}
			while parser.tokenchars_joinable[reader:peek()] do
				table.insert(op, reader:read())
			end
			add_token({
				type = "token",
				value = table.concat(op)
			})
			
		elseif parser.tokenchars_unjoinable[mode] then
			
			add_token({
				type = "token",
				value = reader:read()
			})
			
		elseif mode:match("[A-Za-z_]") then
			
			local id = {reader:read()}
			while reader:peek():match("[A-Za-z0-9_]") do
				table.insert(id, reader:read())
			end
			id = table.concat(id)
			
			if parser.keywords[id] then
				add_token({
					type = "keyword",
					value = id
				})
			else
				add_token({
					type = "identifier",
					value = id
				})
			end
			
		elseif mode:match("[0-9]") or reader:peekmatch("%.[0-9]") then -- number
			
			local token = {type = "number", value = ""}
			local value
			
			if mode == "." then
				value = reader:readmatch("%.[0-9]+")
			elseif reader:peek(2) == "0x" then
				value = reader:readmatch("0x%x+")
			else
				value = reader:readmatch("[0-9]+%.[0-9]+") or reader:readmatch("[0-9]+")
			end
			
			if reader:peek() == "f" then
				value = value .. reader:read()
			elseif reader:peek() == "e" then
				value = value .. reader:readmatch("e[%+%-]?[0-9]+")
			end
			
			token.value = value
			add_token(token)
			
		elseif mode == "\n" then
			add_token({
				type = "newline",
			})
			reader:read()
		elseif mode == "\r" and reader:peek(2) == "\r\n" then
			add_token({
				type = "newline",
			})
			reader:read(2)
		elseif mode:match("%s") then
			add_token({
				type = "whitespace",
				value = reader:readmatch("%s")
			})
		else
			
			add_token({
				type = "unknown",
				value = reader:read()
			})
			
		end
	end
	
	return tokens
end

return parser
