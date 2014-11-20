local parser = {}
parser.strict = false
function parser.problem(str, depth)
	if parser.strict then
		error(str, (depth or 1) + 1)
	end
	warn(str)
end

function parser.assert(...)
	local vals = table.pack(...)
	
	if not vals[1] then
		if parser.strict then
			error(vals[2] or "assert failed", 2)
		else
			warn(vals[2] or "assert failed")
		end
	end
	
	return table.unpack(vals)
end

local stringreader = require("luaflare.util.luaparser.stringreader")

local function fix_lookup_table(tbl)
	for k,v in ipairs(tbl) do
		for i = 1, #v - 1 do -- lookup tables: false: incomplete; true: complete
			local vv = v:sub(1, i)
			if tbl[vv] == nil then -- so we don't overide a "good" one
				tbl[vv] = false
			end
		end
		
		tbl[v] = true
		tbl[k] = nil
	end
end

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
	["while"] = true,
	-- value keywords
	["false"] = true, ["true"] = true, ["nil"] = true
}

-- list of all valid tokens
parser.valid_tokens = {
	"+", "-", "*", "/", "//", "^", "%", "&", "~", "|", ">>",
	"<<", "..", "<", "<=", ">", ">=", "==", "~=", "#",
	",", ";", "(", ")", "[", "]", "{", "}", "...", ".", ":", "::"
}

parser.operator_precedence = {
	["or"] = 1,
	["and"] = 2,
	["<"] = 3, [">"] = 3, ["<="] = 3, [">="] = 3, ["~="] = 3, ["=="] = 3,
	["|"] = 4,
	["~"] = 5,
	["&"] = 6,
	["<<"] = 7, [">>"] = 7,
	[".."] = 8,
	["+"] = 9, ["-"] = 9,
	["*"] = 10, ["/"] = 10, ["//"] = 10, ["%"] = 10,
	["u#"] = 11, ["u-"] = 11, ["u~"] = 11,
	["^"] = 12
}

fix_lookup_table(parser.valid_tokens)

parser.escapers = {
	["x(..)"] = function(str)
		return string.char(tonumber(str, 16))
	end,
	["0(%d%d?%d?)"] = function(str)
		return string.char(tonumber(str)) -- is it base 10?
	end,
	["u{(%x-)}"] = function(str) -- this may be incorrect.... untested
		local ret = ""
		for i = 1, #str, 2 do
			ret = ret .. string.char(tonumber(str:sub(i, i + 1), 16))
		end
		return ret
	end,
	["(%d%d?%d?)"] = function(str)
		return string.char(tonumber(str))
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

parser.brackets_create = {
	["{"] = true, ["("] = true, ["["] = true
}
parser.brackets_destroy = {
	["}"] = true, [")"] = true, ["]"] = true
}

function parser.tokenize(code) expects("string")
	local tokens = {}
	local reader = stringreader.new(code)
	
	local _line = 1
	local _startpos = 1
	local _prev = nil
	local _bracket = nil
	local _brackets = {}
	
	local function add_token(tkn) -- fills some special info in too
		tkn.line = _line
		tkn.range = {_startpos, reader._position - 1}
		tkn.chunk = code:sub(tkn.range[1], tkn.range[2])
		table.insert(tokens, tkn)
		
		if tkn.type == "token" then
			if parser.brackets_destroy[tkn.value] then
				table.remove(_brackets, #_brackets)
				_bracket = _brackets[#_brackets]
			end
			if parser.brackets_create[tkn.value] then
				table.insert(_brackets, tkn.value)
				_bracket = _brackets[#_brackets]
			end
		end
		
		if tkn.type == "unknown" then
			--local ptkn = tokens[#tokens - 1] or error()
			local near = ""
			for i = #tokens - 1, #tokens - 10 do
				near = tokens[i].chunk .. near
			end
			parser.problem(string.format("failed to tokenize at line %d (char: %q, near: %s)", tkn.line, tkn.value, near), 3)
		elseif tkn.type == "newline" then
			_line = _line + 1
		elseif tkn.type ~= "whitespace" and tkn.type ~= "comment" then
			_prev = tkn
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
						
						if not got then parser.problem("unknown escape sequence " .. reader:peek()) end
						
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
			
		elseif parser.valid_tokens[mode] ~= nil then -- false or true
			
			local op = reader:read()
			while parser.valid_tokens[op .. reader:peek()] ~= nil do -- try to be as greedy as possible
				op = op .. reader:read()
			end
			
			add_token({
				type = "token",
				value = op
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
				local isindexer = false
				
				if _prev ~= nil and _prev.type == "token" then
					if _prev.value == "."
						or (_bracket == "{" and _prev.value == ",") -- todo: check if inside { $here = $exp }
						or _prev.value == ":"
						or _prev.value == "::"
						or _prev.value == "{"
					then
						isindexer = true
					end
				end
				
				add_token({
					type = "identifier",
					indexer = isindexer,
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
						table.insert(scope.locals, {name = "self", range = nt.range, token = nt, argument = true})
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
			
			-- if we're appending to a table, don't assign the value to the definition
			local prev = parser.previous_token(tokens, k)
			
			if prev and prev.type ~= "token" or (prev and not (
			                                 prev.value == "."
			                              or prev.value == ":"
			                              or prev.value == ","
			                              or prev.value == "{" )) then -- the 2nd part will only be evaulated if type == "token"
				local curscope = t.scope
				while curscope do
					for k,v in pairs(curscope.locals) do
						if v.name == t.value and v.range[1] < t.range[1] then
							t.defined = v
							v.token.defines = v.token.defines or {}
							table.insert(v.token.defines, t)
							break
						end
					end
					curscope = curscope.parent
				end
			end
		end
	end
	
	parser.assert(root_scope == scope)
	return root_scope
end

function parser.next_token(tokens, k, count) expects("table", "number", nil)
	count = count or 1
	local tk, n = nil, k
	while count > 0 do
		n = n + 1
		tk = tokens[n]
		if not tk then
			return nil, nil
		elseif tk.type ~= "whitespace" and tk.type ~= "newline" and tk.type ~= "comment" then
			count = count - 1
		end
	end
	return tk, n
end
function parser.previous_token(tokens, k, count) expects("table", "number", nil)
	count = count or 1
	local tk, n = nil, k
	while count > 0 do
		n = n - 1
		tk = tokens[n]
		if not tk then
			return nil, nil
		elseif tk.type ~= "whitespace" and tk.type ~= "newline" and tk.type ~= "comment" then
			count = count - 1
		end
	end
	return tk, n
end

function parser.parse(tokens) -- chunk ::= block
	local state = {
		n = 0,
		tokens = tokens
	}
	local tree = {}
	
	local block, err = parser.parse_block(state)
		
	if not block then
		parser.problem(err)
	end
	
	return block
end


function parser.parse_token(state, typ, value)
	local nt, nn = parser.next_token(state.tokens, state.n)
	if nt and nt.type == typ and nt.value == value then
		state.n = nn
		return {
			type = "token",
			subtype = typ,
			token = nt
		}
	end
end

function parser.parse_Name(state)
	local nt, nn = parser.next_token(state.tokens, state.n)
	if nt and nt.type == "identifier" then
		state.n = nn
		return {
			type = "name",
			token = nt
		}
	end
	return nil, "name expected"
end

function parser.parse_Numeral(state)
	local nt, nn = parser.next_token(state.tokens, state.n)
	if nt and nt.type == "number" then
		state.n = nn
		return {
			type = "numeral",
			token = nt
		}
	end
	return nil, "number expected"
end

function parser.parse_LiteralString(state)
	local nt, nn = parser.next_token(state.tokens, state.n)
	if nt and nt.type == "string" then
		state.n = nn
		return {
			type = "string",
			token = nt
		}
	end
	return nil, "string expected"
end

-- all of these must be atomic
function parser.parse_block(state) -- block ::= {stat} [retstat]
	local block = {type = "block"}
	while true do
		local stat, err = parser.parse_stat(state)
		if not stat then
			if err then print(err) end
			break
		end
		table.insert(block, stat)
	end
	
	local rstat, err = parser.parse_retstat(state)
	if rstat then
		table.insert(block, rstat)
	end
	
	return block
end

local function build_error(state, err)
	err = "at " .. state.n .. ": " .. (err or "")
	--print(err)
	return err
end

function parser.parse_stat(state)
	local n = state.n
	if not parser.next_token(state.tokens, state.n) then -- EOF
		return nil
	end
	
	local function reset_state(v, err, ...)
		err = build_error(state, err)
		state.n = n
		return v, err, ...
	end
	
	do -- ‘;’ |
		local sc = parser.parse_token(state, "token", ";")
		if sc then
			return { type = "stat", subtype = "semicolon", semicolon = sc }
		end
	end
	
	do -- varlist ‘=’ explist |
		local varlist = parser.parse_varlist(state)
		if not varlist then goto end_assignment end
		
		local eq = parser.parse_token(state, "token", "=")
		if not eq then reset_state() goto end_assignment end -- wasn't an assignment to begin with
		
		local explist, err = parser.parse_explist(state)
		if not explist then return reset_state(nil, err) end
		
		return {
			type = "stat", subtype = "assignment",
			varlist = varlist, eq = eq, explist = explist
		}
	end ::end_assignment::
	
	do -- functioncall | 
		local fc, err = parser.parse_functioncall(state)
		print(fc, err)
		if fc then
			return {
				type = "stat", subtype = "functioncall", functioncall = fc
			}
		end
	end
	
	do -- label |
		local lbl = parser.parse_label(state)
		if lbl then
			return {
				type = "stat", subtype = "label", label = lbl
			}
		end
	end
	
	do -- 'break' |
		local brk = parser.parse_token(state, "keyword", "break")
		if brk then
			return {
				type = "stat", subtype = "break", ["break"] = brk
			}
		end
	end
	
	do -- 'goto' Name |
		local gt = parser.parse_token(state, "keyword", "goto")
		if not gt then goto end_goto end
		
		local name, err = parser.parse_Name(state)
		if not name then return reset_state(nil, err) end
		
		return {type = "stat", subtype = "goto", ["goto"] = gt, name = name}
	end ::end_goto::
	
	do -- 'do' block 'end'
		local do_ = parser.parse_token(state, "keyword", "do")
		if not do_ then goto end_do end
		
		local block, err = parser.parse_block(state)
		if not block then return reset_state(nil, err) end
		
		local end_ = parser.parse_token(state, "keyword", "end")
		if not end_ then return reset_state(nil, "end expected") end
		
		return {type = "stat", subtype = "do", ["do"] = do_, ["end"] = end_, block = block}
	end ::end_do::
	
	do -- 'while' exp 'do' block 'end' | 
		local while_ = parser.parse_token(state, "keyword", "while")
		if not while_ then goto end_while end
		
		local exp, err = parser.parse_exp(state)
		if not exp then return reset_state(nil, err) end
		
		local do_ = parser.parse_token(state, "keyword", "do")
		if not do_ then return reset_state(nil, "do expected") end
		
		local block, err = parser.parse_block(state)
		if not block then return reset_state(nil, err) end
		
		local end_ = parser.parse_token(state, "keyword", "end")
		if not end_ then return reset_state(nil, "end expected") end
		
		return {
			type = "stat", subtype = "while", ["while"] = while_, ["do"] = do_, ["end"] = end_, exp = exp, block = block
		}
	end ::end_while::
	
	do -- 'repeat' block 'until' exp | 
		local repeat_ = parser.parse_token(state, "keyword", "repeat")
		if not repeat_ then goto end_repeat end
		
		local block, err = parser.parse_block(state)
		if not block then return reset_state(nil, err) end
		
		local until_ = parser.parse_token(state, "keyword", "until")
		if not until_ then return reset_state(nil, "until expected") end
		
		local exp, err = parser.parse_exp(state)
		if not exp then return reset_state(nil, err) end
		
		return {type = "stat", subtype = "repeat", ["repeat"] = repeat_, ["until"] = until_, block = block, exp = exp}
	end ::end_repeat::
	
	do -- 'if' exp 'then' block {'elseif' exp 'then' block} ['else' block] 'end' |
		local if_ = parser.parse_token(state, "keyword", "if")
		if not if_ then goto end_if end
		
		local exp, err = parser.parse_exp(state)
		if not exp then return reset_state(nil, err) end
		
		local then_ = parser.parse_token(state, "keyword", "then")
		if not then_ then return reset_state(nil, "then expected") end
		
		local block, err = parser.parse_block(state)
		if not block then return reset_state(nil, err) end
		
		local ret = {type = "stat", subtype = "if", ["if"] = if_, ["then"] = then_, exp = exp, block = block}
		ret.elseifs = {}
		
		while true do -- read the elseif's
			local elseif_ = parser.parse_token(state, "keyword", "elseif")
			if not elseif_ then break end
			
			local elseif_exp, err = parser.parse_exp(state)
			if not elseif_exp then return reset_state(nil, err) end
			
			local elseif_then = parser.parse_token(state, "keyword", "then")
			if not elseif_then then return reset_state(nil, "then expected") end
			
			local elseif_block, err = parser.parse_block(state)
			if not elseif_block then return reset_state(nil, err) end
			
			table.insert(ret.elseifs, {
				type = "elseif", ["elseif"] = elseif_, ["then"] = elseif_then, exp = elseif_exp, block = elseif_block
			})
		end
		
		-- read the else
		local else_ = parser.read_token(state, "keyword", "else")
		if else_ then
			local else_block, err = parser.read_block(state)
			if not else_block then return reset_state(nil, err) end
			
			ret["else"] = {type = "else", ["else"] = else_, block = else_block}
		end
		
		local end_ = parser.read_token(state, "keyword", "end")
		if not end_ then return reset_state(nil, "end expected") end
		
		ret["end"] = end_
		return ret
	end ::end_if::
	
	do -- 'for' Name ‘=’ exp ‘,’ exp [‘,’ exp] 'do' block 'end' |
		local n = state.n
		
		local for_ = parser.parse_token(state, "keyword", "for")
		if not for_ then goto end_for end
		
		local name, err = parser.parse_Name(state)
		if not name then return reset_state(nil, err) end
		
		local eq = parser.parse_token(state, "token", "=")
		if not eq then -- this is a for namelist in type, reset and continue
			state.n = n
			goto end_for
		end
		
		local exp_from, err = parser.parse_exp(state)
		if not exp_from then return reset_state(nil, err) end
		
		local post_from_comma = parser.parse_token(state, "token", ",")
		if not post_from_comma then return reset_state(nil, ", expected") end
		
		local exp_to, err = parser.parse_exp(state)
		if not exp_to then return reset_state(nil, err) end
		
		local post_to_comma = parser.parse_token(state, "token", ",")
		local step
		
		if post_to_comma then
			step, err = parser.parse_exp(state)
			if not step then return reset_state(nil, err) end
		end
		
		local do_ = parser.parse_token(state, "keyword", "do")
		if not do_ then return reset_state(nil, "do expected") end
		
		local block, err = parser.parse_block(state)
		if not block then return reset_state(nil, err) end
		
		local end_ = parser.parse_token(state, "keyword", "end")
		if not end_ then return reset_state(nil, "end expected") end
		
		return {
			type = "stat", subtype = "for", ["for"] = for_, name = name,
			exp_from = exp_from, exp_to = exp_to, exp_step = step,
			["do"] = do_, block = block, ["end"] = end_
		}
	end ::end_for::
	
	do -- 'for' namelist 'in' explist 'do' block 'end' |
		local for_ = parser.parse_token(state, "keyword", "for")
		if not for_ then goto end_for2 end
		
		local namelist, err = parser.parse_namelist(state)
		if not namelist then return reset_state(nil, err) end
		
		local in_ = parser.parse_token(state, "keyword", "in")
		if not in_ then return reset_state(nil, "in expected") end
		
		local explist, err = parser.parse_explist(state)
		if not explist then return reset_state(nil, err) end
		
		local do_ = parser.parse_token(state, "keyword", "do")
		if not do_ then return reset_state(nil, "do expected") end
		
		local block, err = parser.parse_block(state)
		if not block then return reset_state(nil, err) end
		
		local end_ = parser.parse_token(state, "keyword", "end")
		if not end_ then return reset_state(nil, "end expected") end
		
		return {
			type = "stat", subtype = "for in", ["for"] = for_,
			namelist = namelist,["in"] = in_, explist = explist, ["do"] = do_,
			block = block, ["end"] = end_
		}
	end ::end_for2::
	
	do -- 'function' funcname funcbody |
		local function_ = parser.parse_token(state, "keyword", "function")
		if not function_ then goto end_function end
		
		local funcname, err = parser.parse_funcname(state)
		if not funcname then return reset_state(nil, err) end
		
		local funcbody, err = parser.parse_funcbody(state)
		if not funcbody then return reset_state(nil, err) end
		
		return {
			type = "stat", subtype = "function",
			funcname = funcname, funcbody = funcbody
		}
	end ::end_function::
	
	do -- 'local' 'function' Name funcbody | 'local' namelist [‘=’ explist] 
		local local_ = parser.parse_token(state, "keyword", "function")
		if not local_ then goto end_local end
		
		do -- function Name funcbody |
			local function_ = parser.parse_token(state, "keyword", "function")
			if not function_ then goto end_function end
			
			local name, err = parser.parse_Name(state)
			if not name then return reset_state(nil, err) end
			
			local funcbody, err = parser.parse_funcbody(state)
			if not funcbody then return reset_state(nil, err) end
			
			return {
				type = "stat", subtype = "local function",
				name = name, funcbody = funcbody
			}
		end ::end_function::
		
		local namelist, err = parser.parse_namelist(state)
		if not namelist then return reset_state(nil, err) end
		
		local explist
		local eq = parser.parse_token(state, "token", "=")
		if eq then
			explist, err = parser.parse_explist(state)
			if not explist then return reset_state(nil, err) end
		end
		
		return {
			type = "stat", subtype = "local",
			namelist = namelist, eq = eq, explist = explist
		}
	end ::end_local::
	
	return nil -- no error, just exausted
end

function parser.parse_retstat(state) -- return [explist] [‘;’]
	local return_ = parser.parse_token(state, "keyword", "return")
	if not return_ then return nil end
	
	local explist = parser.parse_explist(state)
	local semicol = parser.parse_token(state, "token", ";")
	
	return {type = "retstat", explist = explist, semicol = semicol}
end

function parser.parse_label(state)
	local n = state.n
	local function reset_state(v, err, ...)
		err = build_error(state, err)
		state.n = n
		return v, err, ...
	end
	
	local dblcol1 = parser.parse_token(state, "token", "::")
	if not dblcol1 then return nil, ":: expected" end
	
	local name, err = parser.parse_Name()
	if not name then return reset_state(nil, err) end
	
	local dblcol2 = parser.parse_token(state, "token", "::")
	if not dblcol2 then return reset_state(nil, ":: expected") end
	
	return {
		type = "label", colons_left = dblcol1, colons_right = dblcol2, name = name
	}	
end

function parser.parse_funcname(state)
	local n = state.n
	local function reset_state(v, err, ...)
		err = build_error(state, err)
		state.n = n
		return v, err, ...
	end
	
	local names = {}
	
	local name, err = parser.parse_Name(state)
	if not name then return reset_state(nil, err) end
	
	names[1] = {name = name, prefix = nil}
	
	while true do
		local dot = parser.parse_token(state, "token", ".")
		if not dot then break end
		
		local name2, err = parser.parse_Name(state)
		if not name2 then return reset_state(nil, err) end
		table.insert(names, {name = name2, prefix = dot})
	end
	
	local colon = parser.parse_token(state, "token", ":")
	if colon then
		local name2, err = parser.parse_Name(state)
		if not name2 then return reset_state(nil, err) end
		table.insert(names, {name = name2, prefix = colon, self = true})
	end
	
	return { type = "funcname", names = names }
end

function parser.parse_varlist(state) -- var {‘,’ var}
	local n = state.n
	local function reset_state(v, err, ...)
		err = build_error(state, err)
		state.n = n
		return v, err, ...
	end
	
	local list = {}
	local var, err = parser.parse_var(state)
	if not var then return reset_state(nil, err) end
	
	table.insert(list, var)
	
	while true do
		local comm = parser.parse_token(state, "token", ",")
		if not comm then break end
		
		var, err = parser.parse_var(state)
		if not var then return reset_state(nil, err) end
		
		table.insert(list, var)
	end
	
	return {type = "varlist", list = list}
end

function parser.parse_var(state) -- Name | prefixexp ‘[’ exp ‘]’ | prefixexp ‘.’ Name 
	local n = state.n
	local function reset_state(v, err, ...)
		err = build_error(state, err)
		state.n = n
		return v, err, ...
	end
	
	local nt = parser.next_token(state.tokens, state.n)
	if not nt then return end
	
	local name = parser.parse_Name(state)
	if name then
		if nt.type == "token" and (nt.value == "[" or nt.value == ".") then
			reset_state()
		else
			return {type = "var", name = name}
		end
	end
	
	local prefixexp = parser.parse_prefixexp(state)
	
	local lsb = parser.parse_token(state, "token", "[")
	if lsb then
		local exp, err = parser.parse_exp(state)
		if not exp then return reset_state(nil, err) end
		
		local rsb = parser.parse_token(state, "token", "]")
		if not rsb then return reset_state(nil, "] expected") end
		
		return {type = "var", prefix = prefixexp, index_exp = exp}
	end
	
	local dot = parser.parse_token(state, "token", ".")
	if not dot then return reset_state(nil, ". expected") end
	
	local index_name, err = parser.parse_Name(state)
	if not index_name then return reset_state(nil, err) end
	
	return {type = "var", prefix = prefixexp, index_name = index_name}
end

function parser.parse_namelist(state)
	local n = state.n
	local function reset_state(v, err, ...)
		err = build_error(state, err)
		state.n = n
		return v, err, ...
	end
	
	local list = {}
	local name, err = parser.parse_Name(state)
	if not name then return reset_state(nil, err) end
	
	table.insert(list, name)
	
	while true do
		local comm = parser.parse_token(state, "token", ",")
		if not comm then break end
		
		name, err = parser.parse_Name(state)
		if not name then return reset_state(nil, err) end
		
		table.insert(list, name)
	end
	
	return {type = "namelist", list = list}
end

function parser.parse_explist(state)
	local n = state.n
	local function reset_state(v, err, ...)
		err = build_error(state, err)
		state.n = n
		return v, err, ...
	end
	
	local list = {}
	local exp, err = parser.parse_exp(state)
	if not exp then return reset_state(nil, err) end
	
	table.insert(list, exp)
	
	while true do
		local comm = parser.parse_token(state, "token", ",")
		if not comm then break end
		
		exp, err = parser.parse_exp(state)
		if not var then return reset_state(nil, err) end
		
		table.insert(list, exp)
	end
	
	return {type = "explist", list = list}
end

function parser.parse_exp(state)
	local n = state.n
	local function reset_state(v, err, ...)
		err = build_error(state, err)
		state.n = n
		return v, err, ...
	end
	
	local r =
		   parser.parse_token(state, "keyword", "nil")
		or parser.parse_token(state, "keyword", "false")
		or parser.parse_token(state, "keyword", "true")
		or parser.parse_Numeral(state)
		or parser.parse_LiteralString(state)
		or parser.parse_token(state, "token", "...")
		or parser.parse_functiondef(state)
		or parser.parse_prefixexp(state)
		or parser.parse_tableconstructor(state)
	
	if r then return {type = "exp", subtype = "main", value = r} end
	
	local exp1 = parser.parse_exp(state)
	if exp1 then
		local op = parser.parse_binop(state)
		if op then
			local exp2, err = parser.parse_exp(state)
			if not exp2 then return reset_state(nil, err) end
			
			return {type = "exp", subtype = "binop", exp1 = exp1, op = op, exp2 = exp2}
		end
	end
	reset_state()
	
	local unop = parser.parse_unop(state)
	if unop then
		local exp1, err = parser.parse_exp(state)
		if not exp1 then return reset_state(nil, err) end
		
		return {type = "exp", subtype = "unop", op = op, exp1 = exp1}
	end
	
	return reset_state(nil, "expected expression")
end

function parser.parse_prefixexp(state)
	local n = state.n
	local function reset_state(v, err, ...)
		err = build_error(state, err)
		state.n = n
		return v, err, ...
	end
	
	local var = parser.parse_var(state)
	if var then return {type = "prefixexp", subtype = "var", var = var} end
	
	local fc = parser.parse_functioncall(state)
	if fc then return {type = "prefixexp", subtype = "functioncall", functioncall = fc} end
	
	local lb = parser.parse_token(state, "token", "(")
	if lb then
		local exp, err = parser.parse_exp(state)
		if not exp then return reset_state(nil, err) end
		
		local rb = parser.parse_token(state, "token", ")")
		if not rb then return reset_state(nil, ") expected") end
		
		return {type = "prefixexp", subtype = "exp", exp = exp}
	end
	
	return nil, "expected prefix exp"
end

function parser.parse_functioncall(state) -- prefixexp args | prefixexp ‘:’ Name args 
	local n = state.n
	local function reset_state(v, err, ...)
		err = build_error(state, err)
		state.n = n
		return v, err, ...
	end
	
	local prefixexp = parser.parse_prefixexp(state)
	if not prefixexp then return reset_state(nil, "expected prefixexp") end
	
	local ret = {type = "functioncall", prefix = prefixexp}
	
	local colon = parser.parse_token(state, "token", ":")
	if colon then
		local name, err = parser.parse_Name(state)
		if not name then return reset_state(nil, err) end
	end
	
	local args, err = parser.parse_args(state)
	if not args then return reset_state(nil, err) end
	ret.args = args
	
	return ret
end

function parser.parse_args(state)
	local n = state.n
	local function reset_state(v, err, ...)
		err = build_error(state, err)
		state.n = n
		return v, err, ...
	end
	
	do
		local lb = parser.parse_token(state, "token", "(")
		if not lb then goto end_brackets end
		
		local explist = parser.parse_explist(state)
		
		local rb = parser.parse_token(state, "token", ")")
		if not rb then return reset_state(nil, ") expected") end
		
		return {type = "args", subtype = "explist", explist = explist}
	end ::end_brackets::
	
	do
		local tablector = parser.parse_tableconstructor(state)
		if tablector then
			return {type = "args", subtype = "tableconstructor", tableconstructor = tablector}
		end
	end
	
	do
		local str = parser.parse_LiteralString(state)
		if tablector then
			return {type = "args", subtype = "string", string = str}
		end
	end
	
	return nil, "arguments expected"
end

function parser.parse_functiondef(state)
	local n = state.n
	local function reset_state(v, err, ...)
		err = build_error(state, err)
		state.n = n
		return v, err, ...
	end
	
	local function_ = parser.parse_token(state, "keyword", "function")
	if not function_ then return reset_state(nil, "function expected") end
	
	local body, err = parser.parse_functionbody(state)
	if not body then return reset_state(nil, err) end
	
	return {type = "functiondef", ["function"] = function_, funcbody = body}
end

function parser.parse_funcbody(state)
	local n = state.n
	local function reset_state(v, err, ...)
		err = build_error(state, err)
		state.n = n
		return v, err, ...
	end
	
	local lb = parser.parse_token(state, "token", "(")
	if not lb then return reset_state(nil, "( expected") end
	
	local parlist = parser.parse_parlist(state)
	
	local rb = parser.parse_token(state, "token", ")")
	if not rb then return reset_state(nil, ") expected") end
	
	local block, err = parser.parse_block(state)
	if not block then return reset_state(nil, err) end
	
	local end_ = parser.parse_token(state, "keyword", "end")
	if not end_ then return reset_state(nil, "end expected") end
	
	return {type = "funcbody", parlist = parlist, ["end"] = end_}
end

function parser.parse_parlist(state) -- parlist ::= namelist [‘,’ ‘...’] | ‘...’
	local n = state.n
	local function reset_state(v, err, ...)
		err = build_error(state, err)
		state.n = n
		return v, err, ...
	end
	
	local namelist = parser.parse_namelist()
	local ret = { type = "parlist", namelist = namelist }
	
	if namelist then
		local comm = parser.parse_token(state, "token", ",")
		if comm then
			local ddd = parser.parse_token(state, "token", "...")
			if not ddd then return reset_state(nil, "... or name expected") end
			ret.ellipsis = ddd
		end
	else
		local ddd = parser.parse_token(state, "token", "...")
		ret.ellipsis = ddd
	end
	
	return ret
end

function parser.parse_tableconstructor(state)
	local n = state.n
	local function reset_state(v, err, ...)
		err = build_error(state, err)
		state.n = n
		return v, err, ...
	end
	
	local lb = parser.parse_token(state, "token", "{")
	if not lb then return reset_state(nil, "{ expected") end
	
	local fieldlist = parser.parse_fieldlist(state)
	
	local rb = parser.parse_token(state, "token", "}")
	if not rb then return reset_state(nil, "} expected") end
	
	return {rb = rb, lb = lb, fieldlist = fieldlist}
end

function parser.parse_fieldlist(state) -- fieldlist ::= field {fieldsep field} [fieldsep]
	local n = state.n
	local function reset_state(v, err, ...)
		err = build_error(state, err)
		state.n = n
		return v, err, ...
	end
	
	local field, err = parser.parse_field(state)
	if not field then return reset_state(nil, err) end
	
	local list = {field}
	
	while true do
		local sep = parser.parse_fieldsep(state)
		if not sep then break end
		
		local field = parser.parse_field(state)
		if not field then break end
		
		table.insert(list, field)
	end
	
	return {type = "fieldlist", list = list}
end

function parser.parse_field(state) -- field ::= ‘[’ exp ‘]’ ‘=’ exp | Name ‘=’ exp | exp
	local n = state.n
	local function reset_state(v, err, ...)
		err = build_error(state, err)
		state.n = n
		return v, err, ...
	end
	
	local lsb = parser.parse_token(state, "token", "[")
	if lsb then
		local lexp, err = parser.parse_exp(state)
		if not lexp then return reset_state(nil, err) end
		
		local rsb, err = parser.parse_token(state, "token", "]")
		if not rsb then return reset_state(nil, "] expected") end
		
		local eq, err = parser.parse_token(state, "token", "=")
		if not eq then return reset_state(nil, "= expected") end
		
		local rexp, err = parser.parse_exp(state)
		if not rexp then return reset_state(nil, err) end
		
		return {type = "field", subtype = "exp key", lexp = lexp, rexp = rexp}
	end
	
	local nn = state.n
	local name = parser.parse_Name(state)
	if name then
		local eq = parser.parse_token(state, "token", "=")
		if not eq then goto end_nameeq end -- go and try exp
		do
			local rexp, err = parser.parse_exp(state)
			if not rexp then return reset_state(nil, err) end
		
			return {type = "field", subtype = "name key", name = name, rexp = rexp}
		end
		::end_nameeq::
		state.n = nn
	end
	
	local exp, err = parser.parse_exp(state)
	if not exp then return reset_state(nil, err) end
	
	return {type = "field", subtype = "exp", exp = exp}
end

function parser.parse_fieldsep(state) -- fieldsep ::= ‘,’ | ‘;’
	local r = parser.parse_token(state, "token", ",") or parser.parse_token(state, "token", ";")
	if r then
		return {type = "fieldsep", sep = r}
	end
	return nil, ", or ; expected"
end

function parser.parse_binop(state)
	local r = 
		   parser.parse_token(state, "token", "+")
		or parser.parse_token(state, "token", "-")
		or parser.parse_token(state, "token", "*")
		or parser.parse_token(state, "token", "/")
		or parser.parse_token(state, "token", "//")
		or parser.parse_token(state, "token", "^")
		or parser.parse_token(state, "token", "%")
		or parser.parse_token(state, "token", "&")
		or parser.parse_token(state, "token", "~")
		or parser.parse_token(state, "token", "|")
		or parser.parse_token(state, "token", ">>")
		or parser.parse_token(state, "token", "<<")
		or parser.parse_token(state, "token", "..")
		or parser.parse_token(state, "token", "<")
		or parser.parse_token(state, "token", "<=")
		or parser.parse_token(state, "token", ">")
		or parser.parse_token(state, "token", ">=")
		or parser.parse_token(state, "token", "==")
		or parser.parse_token(state, "token", "~=")
		or parser.parse_token(state, "keyword", "and")
		or parser.parse_token(state, "keyword", "or")
	
	return {type = "binop", op = v}
end

function parser.parse_unop(state)
	local r = 
		   parser.parse_token(state, "token", "-")
		or parser.parse_token(state, "keyword", "not")
		or parser.parse_token(state, "token", "#")
		or parser.parse_token(state, "token", "~")
	
	return {type = "unop", op = v}
end

return parser
