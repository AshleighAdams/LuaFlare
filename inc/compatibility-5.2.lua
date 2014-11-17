
if not _VERSION:match("5%.2") then
	return
end

local hook = require("luaserver.hook")
local parser = require("luaserver.util.luaparser")

print("warning: running under 5.2 compatibility layer, please think about moving to a more recent Lua version.")

function lua53_idiv(a, b)
	-- for now, fall back to this:
	math.floor(a / b)
end

local function add_53_operators(tokens)
	-- a & b
	-- a | b
	-- a ~ b
	-- a << b
	-- a >> b
	-- a // b
	
	local new_ops_func_map = {
		["&"]  = "bit32.band",
		["|"]  = "bit32.bor",
		["~"]  = "bit32.bxor",
		["<<"] = "bit32.lshift",
		[">>"] = "bit32.rshift",
		["//"] = "lua53_idiv"
	}
	
	local okay_token_types = {
		identifier = true,
		number = true,
		string = true
	}
	
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
				--[[
				pt.chunk = replacement_func .. "(" .. pt.chunk
				pt.value = replacement_func .. "(" .. pt.value
				v.chunk = ","
				v.value = ","
				nt.chunk = nt.chunk .. ")"
				nt.value = nt.value .. ")"]]
			end
		end
	end
end
hook.add("ModifyTokens", "5.2 -> 5.3: new operators", add_53_operators)
























