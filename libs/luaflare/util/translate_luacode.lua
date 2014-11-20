local parser = require("luaflare.util.luaparser")
local hook = require("luaflare.hook")

local rgx = "function$ $maybename$ %($args%)"
rgx = rgx:replace("$maybename", "([A-z0-9_%.:]*)")
rgx = rgx:replace("$ ", "%s*")
rgx = rgx:replace("$args", "([A-z0-9_, %*&%.]-)")

local function translate_luacode_regex(code)
	code = code:gsub(rgx, function(name, argslist)
		local args = argslist:split(",")
		local expects_tbl = {}
		local args_tbl = {}
		local hastype = false
	
		local meta_tbl = name:match("(.+):.+")
		local meta_tbl_check = name:match("(.+)::.+")
		if meta_tbl_check then
			hastype = true
			table.insert(expects_tbl, meta_tbl_check)
			name = name:replace("::", ":")
		elseif meta_tbl then
			hastype = false
			table.insert(expects_tbl, "nil")
		end
	
		for _, arg in pairs(args) do
			local arg_split = arg:trim():split(" ", {remove_empty = true})
			local arg_name, arg_type
			
			if #arg_split == 1 then
				arg_name = arg_split[1]:trim()
			else
				arg_name = arg_split[2]:trim()
				arg_type = arg_split[1]:trim()
			end
			
			table.insert(args_tbl, arg_name)
		
			if not arg_type then
				table.insert(expects_tbl, "nil")
			else
				local len_type = #arg_type
				if arg_type:sub(len_type, len_type) == "&" then
					table.insert(expects_tbl, arg_type:sub(1, -2)) -- from the start, to the last but 1 (removing the &)
				else
					table.insert(expects_tbl, '"' .. arg_type .. '"')
				end
			end
		

			hastype = hastype or arg_type
		end
	
		local expects_str = ""
	
		if hastype then
			expects_str = " expects(" .. table.concat(expects_tbl, ", ") .. ")"
		end
	
		return string.format("function %s (%s)", name, table.concat(args_tbl, ", ")) .. expects_str
	end)
	
	return code
end


local function translate_luacode_tokens(code)
	local tokens = parser.tokenize(code)
	local buff = {}
	
	hook.Call("ModifyTokens", tokens)
	hook.Call("OptimizeTokens", tokens)
	
	for k,token in pairs(tokens) do
		table.insert(buff, token.chunk)
	end
	
	return table.concat(buff)
end

return translate_luacode_tokens --regex
