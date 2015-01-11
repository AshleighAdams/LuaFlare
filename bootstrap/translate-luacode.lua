local parser = require("luaflare.util.luaparser")
local hook

local function translate_luacode(code, extra_hooks)
	if not hook then
		hook = require("luaflare.hook")
	end
	
	local tokens = parser.tokenize(code)
	local buff = {}
	
	hook.call("ModifyTokens", tokens)
	if extra_hooks and extra_hooks.ModifyTokens then extra_hooks.ModifyTokens(tokens) end
	hook.call("OptimizeTokens", tokens)
	if extra_hooks and extra_hooks.OptimizeTokens then extra_hooks.OptimizeTokens(tokens) end
	
	for k,token in pairs(tokens) do
		table.insert(buff, token.chunk)
	end
	
	return table.concat(buff)
end

return translate_luacode --regex
