local v = tonumber(_VERSION:match("%d.%d"))
if v > 5.2 then
	return
end

bootstrap.log("warning: running under 5.2 compatibility layer, please think about moving to a more recent Lua version.")

local hook = require("luaflare.hook")
local parser = require("luaflare.util.luaparser")

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

-- TODO: the precedence on these is not perfect, but it's sort of okay (does not currently work with unary operators)
local function add_53_operators(tokens)
	for k,v in pairs(tokens) do
		if v.type == "token" and new_ops_func_map[v.value] then
			-- this opperator is new in 5.3
			local replacement_func = new_ops_func_map[v.value]
			local precedence = parser.operator_precedence[v.value]
			
			if not precedence then
				parser.problem("no operator precedence for " .. v.value)
				break
			end
			
			--local pt, pn = parser.previous_token(tokens, k, 1)
			--local nt, nn = parser.next_token(tokens, k, 1)
			
			local pt, pn = nil, k
			local nt, nn = nil, k
			local depth
			
			depth = 0
			while true do
				local t, n = parser.previous_token(tokens, pn, 1)
				
				if t.type == "token" then
					if t.value == ":" or t.value == "." then
						-- ignore these
					else -- depth here will go < 0
						local depthchanged = false
						if parser.brackets_create[t.value] then
							depth  = depth + 1
							depthchanged = true
						end
						if parser.brackets_destroy[t.value] then
							depth = depth - 1
							depthchanged = true
						end
						
						-- if we were located in brackets, exit
						-- if other_precedence is set, this is a math operation (usually)
						local other_precedence = parser.operator_precedence[t.value]
						
						if depth > 0 then
							break
						elseif depth == 0 and other_precedence then
							if other_precedence < precedence then
								break
							end
						elseif depth == 0 and not depthchanged then -- end of statement
							break
						end
					end
				elseif depth == 0 and t.type == "keyword" then
					break
				end
				
				pn = n
			end
			
			depth = 0
			while true do
				local t, n = parser.next_token(tokens, nn, 1)
				
				if t.type == "token" then
					if t.value == ":" or t.value == "." then
						-- ignore these
					else -- depth here will go < 0
						local depthchanged = false
						if parser.brackets_create[t.value] then
							depth  = depth + 1
							depthchanged = true
						end
						if parser.brackets_destroy[t.value] then
							depth = depth - 1
							depthchanged = true
						end
						
						-- if we were located in brackets, exit
						local other_precedence = parser.operator_precedence[t.value]
						
						if depth < 0 then
							break
						elseif depth == 0 and other_precedence then
							if other_precedence < precedence then
								break
							end
						elseif depth == 0 and not depthchanged then -- end of statement
							break
						end
					end
				elseif depth == 0 and t.type == "keyword" then
					break
				end
				
				nn = n
			end
			
			table.insert(tokens, nn + 1, {type = "token", value = ")", chunk = ")"})
			table.insert(tokens, pn    , {type = "token", value = "(", chunk = "("})
			table.insert(tokens, pn    , {type = "identifier", value = replacement_func, chunk = replacement_func})
			v.value = ","
			v.chunk = ","
		end
	end
end
hook.add("ModifyTokens", "5.2 -> 5.3: new operators", add_53_operators)
























