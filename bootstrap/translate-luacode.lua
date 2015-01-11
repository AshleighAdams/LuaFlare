local parser = require("luaflare.util.luaparser")
local hook

local function translate_luacode(code)
	if not hook then
		hook = require("luaflare.hook")
	end
	
	local tokens = parser.tokenize(code)
	local buff = {}
	
	hook.call("ModifyTokens", tokens)
	hook.call("OptimizeTokens", tokens)
	
	for k,token in pairs(tokens) do
		table.insert(buff, token.chunk)
	end
	
	return table.concat(buff)
end

return translate_luacode --regex
