local parser = {}
parser.strict = false
function parser.problem(str, depth)
	if parser.strict then
		error(str, (depth or 1) + 1)
	end
end

function parser.assert(...)
	if parser.strict then
		local vals = table.pack(...)
		if not vals[1] then
			error(vals[2] or "assert failed", 2)
		end
		return table.unpack(vals)
	end
end

local stringreader = require("luaserver.util.luaparser.stringreader")

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
	[">"] = true, ["."] = true, [":"] = true
}
parser.tokenchars_unjoinable = {
	["("] = true, [")"] = true, ["["] = true, ["]"] = true, ["{"] = true,
	["}"] = true, [";"] = true, [","] = true
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

function parser.tokenize(code) expects("string")
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
			--local ptkn = tokens[#tokens - 1] or error()
			local near = ""
			for i = #tokens - 1, #tokens - 10 do
				near = tokens[i].chunk .. near
			end
			parser.problem(string.format("failed to tokenize at line %d (char: %q, near: %s)", tkn.line, tkn.value, near), 3)
		elseif tkn.type == "newline" then
			_line = _line + 1
		end
		_startpos = reader._position
	end
	
	while not reader:eof() do
		local mode = reader:peek()
		
		if _startpos == 1 and reader:peek(2) == "#!" then
			local buff = {}
			while reader:peek() ~= "\n" and reader:peek(2) ~= "\r\n" do
				table.insert(buff, reader:read())
			end
			
			add_token({
				type = "hashbang",
				value = table.concat(buff)
			})
		elseif reader:peek(2) == "--" then
			
			reader:read(2) --
			local block = reader:peek() == "["
			local value
			
			if not block then
				local buff = {}
				while reader:peek() ~= "\n" and reader:peek(2) ~= "\r\n" do
					table.insert(buff, reader:read())
				end
				value = table.concat(buff)
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
			reader:read()
			add_token({
				type = "newline",
			})
		elseif mode == "\r" and reader:peek(2) == "\r\n" then
			reader:read(2)
			add_token({
				type = "newline",
			})
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

-- things that create scopes
parser.scope_create = {
	["do"] = true, ["then"] = true, ["repeat"] = true, ["else"] = true, ["function"] = true
}
-- ends scopes
parser.scope_destroy = {
	["end"] = true, ["elseif"] = true, ["until"] = true, ["else"] = true
}

function parser.read_scopes(tokens) expects("table")
	local root_scope = {
		starts = 1,
		ends = -1,
		starttoken = tokens[1],
		locals = {},
		children = {}
	}
	
	local scope = root_scope
	
	local function push_scope(cur)
		local nscope = {
			parent = scope,
			starts = cur.range[2], -- end of keyword
			ends = -1,
			starttoken = cur,
			locals = {},
			children = {}
		}
		table.insert(scope.children, nscope)
		scope = nscope
	end
	
	local function pop_scope(cur)
		scope.ends = cur.range[1] -- start of keyword
		scope.endtoken = cur
		scope = assert(scope.parent)
	end
	
	for k, t in pairs(tokens) do
		t.scope = scope
		
		if t.type == "keyword" then
			local val = t.value
			
			if parser.scope_destroy[val] then
				pop_scope(t)
			end if parser.scope_create[val] then -- both can be triggered, needs to be this order too
				push_scope(t)
			end
			
			local tkpos = k
			local function next_token(peek)
				tkpos = tkpos + 1
				local r = tokens[tkpos]
				
				if not r then
					if peek then tkpos = tkpos - 1 end
					return nil, nil
				elseif r.type == "whitespace" or r.type == "newline" then
					local nt, p = next_token(peek)
					if peek then tkpos = tkpos - 1 end
					return nt, p
				else
					if peek then tkpos = tkpos - 1 end
					return r, tkpos
				end
			end
			
			if val == "local" then -- locals (does not read local function's scope)
				
				local nt = next_token(true)
				
				if nt.type == "keyword" and nt.value == "function" then -- local function
					next_token()
					local n = next_token()
					parser.assert(n.type == "identifier")
					table.insert(scope.locals, {name = n.value, range = n.range, token = n})
				else
					while true do
						local n = next_token()
						parser.assert(n.type == "identifier")
						table.insert(scope.locals, {name = n.value, range = n.range, token = n})
						
						n = next_token(true)
						if not (n.type == "token" and n.value == ",") then
							break
						else
							next_token()
						end
					end
				end
				
			elseif val == "function" then -- read arguments
				
				while true do
					local nt = next_token()
					if not nt then break end
					if nt.type == "token" and nt.value == ":" then -- : -> self
						table.insert(scope.locals, {name = "self", range = nt.range, token = nt})
					end
					if nt.type == "token" and nt.value == "(" then break end
				end
				
				while true do
					local nt = next_token()
					if not nt then break end
					if nt.type == "token" and nt.value == ")" then break end
					
					if nt.type == "identifier" then
						table.insert(scope.locals, {name = nt.value, range = nt.range, token = nt, argument = true})
					end
				end
			elseif val == "for" then
				
				while true do
					local n = next_token()
					parser.assert(n.type == "identifier")
					table.insert(scope.locals, {name = n.value, range = n.range, token = n})
					
					n = next_token(true)
					if not (n.type == "token" and n.value == ",") then
						break
					else
						next_token()
					end
				end
				
			end
		elseif t.type == "identifier" then
			
			local curscope = t.scope
			while curscope do
				for k,v in pairs(curscope.locals) do
					if v.name == t.value and v.range[1] < t.range[1] then
						t.defined = v
						v.defines = v.defines or {}
						table.insert(v.defines, t)
						break
					end
				end
				curscope = curscope.parent
			end
			
		end
	end
	
	parser.assert(root_scope == scope)
	return root_scope
end

return parser
