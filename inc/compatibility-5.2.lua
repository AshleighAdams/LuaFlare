
if not _VERSION:match("5%.2") then
	return
end

local hook = require("luaflare.hook")
local parser = require("luaflare.util.luaparser")

print("warning: running under 5.2 compatibility layer, please think about moving to a more recent Lua version.")

lua53_bitand = assert(bit32.band)
lua53_bitor = assert(bit32.bor)
lua53_bitxor = assert(bit32.bxor)
lua53_bitlshift = assert(bit32.lshift)
lua53_bitrshift = assert(bit32.rshift)
lua53_idiv = function(a, b)
	-- for now, fall back to this:
	math.floor(a / b)
end

local new_ops_func_map = {
	["&"]  = "lua53_bitand",
	["|"]  = "lua53_bitor",
	["~"]  = "lua53_bitxor",
	["<<"] = "lua53_bitlshift",
	[">>"] = "lua53_bitrshift",
	["//"] = "lua53_idiv"
}

--[[
local function prev_value(tokens, k, precedence)
	if type(precedence) == "string" then
		precedence = assert(parser.operator_precedence[precedence])
	end
	
	local depth = 0, tk
	while true do
		tk, k = parser.previous_token(tokens, k, 1)
		
		if tk.type == "token" and parser.brackets_create[tk.value] then
			depth = depth + 1
			
			-- check for identifiers
			local prv, pk = parser.previous_token(tokens, k, 1)
			
			if prv.type == "identifier" then
				tk, k = prv, pk
			end
		end
		if tk.type == "token" and parser.brackets_destroy[tk.value] then
			depth = depth - 1
		end
		
		local prv, pk = parser.previous_token(tokens, k, 1)
		-- -(a) << b == (-(a)) << b
		if depth == 0 then
			break
		end
	end
end

local function add_53_bitshift(tokens)
	for k,v in pairs(tokens) do
		if v.type == "token" and (v.value == "<<" or v.value == ">>") then
			
		end
	end
end]]

local okay_token_types = {
	identifier = true,
	number = true,
	string = true
}
local new_ops_func_map = {
	["&"]  = "lua53_bitand",
	["|"]  = "lua53_bitor",
	["~"]  = "lua53_bitxor",
	["<<"] = "lua53_bitlshift",
	[">>"] = "lua53_bitrshift",
	["//"] = "lua53_idiv"
}

-- not 100% complete, (5) | b won't work
-- TODO
local function add_53_operators(tokens)
	for k,v in pairs(tokens) do
		if v.type == "token" and new_ops_func_map[v.value] then
			-- this opperator is new in 5.3
			local replacement_func = new_ops_func_map[v.value]
			
			local pt, pn = parser.previous_token(tokens, k, 1)
			local nt, nn = parser.next_token(tokens, k, 1)
			
			if okay_token_types[pt.type] and okay_token_types[nt.type] then
				table.insert(tokens, nn + 1, {type = "token", value = ")", chunk = ")"})
				table.insert(tokens, pn    , {type = "token", value = "(", chunk = "("})
				table.insert(tokens, pn    , {type = "identifier", value = replacement_func, chunk = replacement_func})
				v.value = ","
				v.chunk = ","
			end
		end
	end
end
hook.add("ModifyTokens", "5.2 -> 5.3: new operators", add_53_operators)
























