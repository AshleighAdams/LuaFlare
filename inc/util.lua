-- All extensions to inbuilt libs use ThisCase
-- incase these libs wen't created
table = table or {}
string = string or {}
escape = escape or {}

------ Table functions
function PrintTable(tbl, done, depth)
	if tbl == nil then error("argument #1 is nil", 2) end
	
	done = done or {}
	depth = depth or 0
	if done[tbl] then return end
	done[tbl] = true
	
	local tabs = string.rep("\t", depth)
	
	for k, v in pairs(tbl) do
		if type(v) == "table" then
			print(tabs .. tostring(k) .. ":")
			PrintTable(v, done, depth + 1)
		else
			print(tabs .. tostring(k) .. " = " .. tostring(v))
		end
	end
end

function table.Count(tbl)
	if tbl == nil then error("argument #1 is nil", 2) end
	
	local count = 0
	for k,v in pairs(tbl) do
		count = count + 1
	end
	
	return count
end

function table.IsEmpty(tbl)
	if tbl == nil then error("argument #1 is nil", 2) end
	
	for k,v in pairs(tbl) do
		return false
	end
	return true
end

function table.HasKey(tbl, key) -- if not tbl[key] then -- < is an error if is 0 or false
	if tbl == nil then error("argument #1 is nil", 2) end
	
	return tbl[key] ~= nil
end

function table.HasValue(tbl, value)
	if tbl == nil then error("argument #1 is nil", 2) end
	
	for k,v in pairs(tbl) do
		if v == value then
			return true, k
		end
	end
	return false, nil
end


-- Table to string
function to_lua_value(var, notable)
	local val = tostring(var)
	
	if type(var) == "string" then
		val = val:gsub("\\", "\\\\")
		val = val:gsub("\n", "\\n")
		val = val:gsub("\t", "\\t")
		val = val:gsub("\r", "\\r")
		val = val:gsub("\"", "\\\"")
		
		val = "\"" .. val .. "\""
	elseif type(var) == "table" and not notable then
		return to_lua_table(var)
	end
	
	return val
end

local function to_lua_table_key(key)
	if type(key) == "string" then
		if key:match("[A-z_][A-z_0-9]*") == key then
			return key
		end
		return "[" .. to_lua_value(key) .. "]"
	else
		return "[" .. to_lua_value(key) .. "]"
	end
end

function to_lua_table(tbl, depth, done)
	if table.IsEmpty(tbl) then return "{}" end
	
	depth = depth or 1
	done = done or {}
	done[tbl] = true
	
	local ret = "{\n"
	local tabs = string.rep("\t", depth)
	
	for k, v in pairs(tbl) do
		ret = ret .. tabs .. to_lua_table_key(k) .. " = "
		
		if type(v) ~= "table" or done[v] then
			ret = ret .. to_lua_value(v, true)
		else
			ret = ret .. to_lua_table(v, depth + 1, done)
		end
		
		ret = ret .. ",\n"
	end
	
	-- remove last comma
	ret = ret:sub(1, ret:len() - 2) .. "\n"
	
	tabs = string.rep("\t", depth - 1)
	ret = ret .. tabs .. "}"
	return ret
end

function table.ToString(tbl)
	if tbl == nil then error("argument #1 is nil", 2) end
end

------- String functions

function string.StartsWith(haystack, needle)
	return haystack:sub(1, needle:len()) == needle
end

function string.EndsWith(haystack, needle)
	return needle == "" or haystack:sub(-needle:len()) == needle
end

function string.Trim(str, chars)
	error("Not implimented", 2)
end

function string.Replace(str, what, with)
	return str:gsub(escape.pattern(what), escape.pattern(with))
end

------- escape functions, try not to use string.Replace, as it is slower than raw gsub

function escape.pattern(input) -- defo do not use string.Replace, else revusion err
	if input == nil then error("argument #1 is nil", 2) end
	
	input = input:gsub("%%", "%%%%") -- escape %'s, and others
	
	input = input:gsub("%.", "%%.")
	input = input:gsub("%*", "%%*")
	input = input:gsub("%(", "%%(")
	input = input:gsub("%)", "%%)")
	input = input:gsub("%+", "%%+")
	
	return input
end

function escape.html(input, strict)
	if input == nil then error("argument #1 is nil", 2) end
	
	if strict == nil then strict = true end
	
	input = input:gsub("&", "&amp;")
	input = input:gsub('"', "&quot;")
	input = input:gsub("'", "&apos;")
	input = input:gsub("<", "&lt;")
	input = input:gsub(">", "&gt;")
	
	if strict then
		input = input:gsub("\t", "&nbsp;&nbsp;&nbsp;&nbsp;")
		input = input:gsub("\n", "<br />\n")
	end
	return input
end

function escape.sql(input)
	if input == nil then error("argument #1 is nil", 2) end
	
	input = input:gsub("'", "\\'")
	input = input:gsub("\"", "\\\"")
	
	return input
end
