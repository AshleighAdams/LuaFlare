local hook = require("luaserver.hook")
local parser = require("luaserver.util.luaparser")

-- for passing raw values
parser.tokenchars_unjoinable["&"] = true

local function add_expects(tokens)
	local toinsert = {}
	
	local function parse_func(k)
		local table_to = {}
		local types, checktypes = {}, false
		local name = ""
		
		while true do
			k = k + 1
			local t = tokens[k]
			if t.type == "identifier" then
				name = t.value
			elseif t.type == "token" and t.value == "." then
				table.insert(table_to, name)
				name = ""
			elseif t.type == "token" and t.value == ":" then
				table.insert(table_to, name)
				name = ""
				table.insert(types, "nil")
			elseif t.type == "token" and t.value == "::" then
				table.insert(table_to, name)
				name = ""
				table.insert(types, table.concat(table_to, "."))
				checktypes = true
				t.chunk = ":" -- convert the chunk value back to : as it should be
				t.value = ":"
			elseif t.type == "token" and t.value == "(" then
				break
			end
		end
		
		-- now we're at the (
		local ids = {}
		local raw = false
		while true do
			k = k + 1
			local t = tokens[k]
			
			local function check_arg_type()
				if #ids == 1 then
					table.insert(types, "nil")
				elseif #ids == 2 then
					if ids[1].raw then
						table.insert(types, ids[1].value)
					else
						table.insert(types, '"' .. ids[1].value .. '"')
					end
					
					tokens[ids[1].index].remove = true -- mark it for removal
					local i = 1
					while true do -- remove the trailing whitespace too
						local t = tokens[ids[1].index + i]
						i = i + 1
						if t.type == "whitespace" then
							t.remove = true
						elseif not t.remove then
							break
						end
					end
					
					checktypes = true
				elseif #ids == 0 then
				else
					error("needs 1 or 2 identifiers to an argument type, got " .. #ids)
				end
				
				ids = {}
				raw = false
			end
			
			if t.type == "identifier" or t.type == "keyword" then -- to allow function type
				local next_token = tokens[k+1]
				local israw = false
				
				if next_token.type == "token" and next_token.value == "&" then
					israw = true
					next_token.remove = true
				end
				
				table.insert(ids, {
					index=k,
					value=t.value,
					raw = israw
				})
			elseif t.type == "token" and t.value == "," then
				check_arg_type()
			elseif t.type == "token" and t.value == ")" then
				check_arg_type()
				break
			end
		end
		
		if checktypes then
			k = k + 1
			
			table.insert(tokens, k, {
				type = "whitespace",
				value = " ",
				chunk = " "
			})
			k = k + 1
			table.insert(tokens, k, {
				type = "identifier",
				value = "expects",
				chunk = "expects"
			})
			k = k + 1
			table.insert(tokens, k, {
				type = "token",
				value = "(",
				chunk = "("
			})
			k = k + 1
			
			local ct = #types
			for i = 1, ct do
				local tktype = "string"
				local val = types[i]
				
				if     val == "nil"        then tktype = "keyword"
				elseif val:sub(1,1) ~= '"' then tktype = "identifier"
				end
				
				table.insert(tokens, k, {
					type = tktype,
					value = val,
					chunk = val
				})
				k = k + 1
					
				if i ~= ct then
					table.insert(tokens, k, {
						type = "token",
						value = ",",
						chunk = ","
					})
					k = k + 1
					table.insert(tokens, k, {
						type = "whitespace",
						value = " ",
						chunk = " "
					})
					k = k + 1
				end
			end
			
			table.insert(tokens, k, {
				type = "token",
				value = ")",
				chunk = ")"
			})
			k = k + 1
		end
	end
	
	for k,v in pairs(tokens) do
		if v.type == "keyword" and v.value == "function" then
			parse_func(k)
		end
	end
	
	-- remove those marked for removal
	for i = #tokens, 1, -1 do
		if tokens[i].remove then
			table.remove(tokens, i)
		end
	end
end
hook.Add("ModifyTokens", "Lua function args strict typing", add_expects)
