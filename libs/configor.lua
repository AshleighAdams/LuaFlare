--[[
Copyright (c) 2014 Kate Adams

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]

local configor = {}

local function table_count(tbl)
	local count = 0
	for k,v in next, tbl do
		count = count + 1
	end
	
	return count
end

-- this function is just type checking
if not expects then expects = function() end end

-- configor node
local node = {}

configor.to_string = {}
configor.to_string.string = function(val) return val end
configor.to_string.number = function(val) return tostring(val) end
configor.to_string.boolean = function(val) return tostring(val) end

configor.from_string = {}
configor.from_string.string = function(str, def) return str == "" and def or str, str == "" end
configor.from_string.number = function(str, def) local r = tonumber(str) return r ~= nil and r or def, r == nil end
configor.from_string.boolean = function(str, def) return str == "" and def, true or str == "true", false end


function node.make(parent, name)
	local nde = {}
	nde._name = name
	nde._value = ""
	nde._cached_val = ""
	nde._value_type = "nil"
	nde._parent = parent
	nde._children = {}
	nde._self = nde
	nde._missed_cache = false
	nde._cache = {} -- this is the cache for accessing child nodes (needed so sorting is the same)
	
	setmetatable(nde, node)
	
	if parent then
		parent:add_child(nde)
	end
	
	return nde
end

function node.__index(tbl, key) expects("table", "string")
	if rawget(node, key) then -- for __call method, yield this
		return rawget(node, key)
	end
	return rawget(tbl, "_self"):get_child(key) or node.make(rawget(tbl, "_self"), key)
end


function node:name()  expects(node)
	return rawget(self, "_name")
end
function node:data()
	return rawget(self, "_value")
end
function node:set_name(name) expects(node, "string")
	rawset(self, "_name", name)
end
function node:parent() expects(node)
	return rawget(self, "_parent")
end

function node:has_children() expects(node)
	return table_count(self:children()) ~= 0
end
function node:children() expects(node)
	return rawget(self, "_children")
end
function node:get_child(key) expects(node, "string")
	local cache = rawget(self, "_cache")
	if cache[key] then return cache[key] end
	
	for k,v in pairs(self._children) do
		if v:name() == key then
			cache[key] = v
			return v
		end
	end
	return nil -- wasn't found
end
function node:add_child(node) expects(node, node)
	table.insert(self._children, node)
end
function node:remove_child(node) expects(node, node)
	local name = node:name()
	if self._cache[name] == node then self._cache[name] = nil end
	for k,v in pairs(self._children) do
		if v == node then
			table.remove(self._children, k)
			return
		end
	end
end

function node:value(default) expects(node, "any")
	local typ = type(default)
	if typ == self._value_type then
		return self._cached_val
	elseif self._missed_cache then
		print("configor: cache miss (check types)", debug.traceback())
	else
		self._missed_cache = true -- the first one will miss the cache
		-- this allows some form of type saftey
	end
	
	local from_str = configor.from_string[typ]
	if from_str == nil then error("no configor.from_string." .. typ .. " defined", 2) end
	
	local val, changed = from_str(self._value, default)
	
	self._value_type = typ
	self._cached_val = val
	
	if changed then
		self:set_value(val)
	end
	
	return val
end
function node:set_value(value) expects(node, "any")
	local typ = type(value)
	
	self._value = configor.to_string[typ](value)
	self._value_type = typ
	self._cached_val = value
end

--

local function inrange(val, ...)
	local args = {...}
	local count = 0
	for i = 1, #args do
		local min, max = args[i][1], args[i][2]
		if val >= min and val <= max then
			return true
		end
	end
	return false
end
-- returns end position, string
local function parse_hex(str, pos, len)
	if pos + 2 > len then
		return nil, "not enough room to parse hex literal"
	end
	
	local a = str:sub(pos + 1, pos + 1):lower()
	local b = str:sub(pos + 2, pos + 2):lower()
	
	if not inrange(a, {"a", "f"}, {"0", "9"}) or not inrange(b, {"a", "f"}, {"0", "9"}) then
		return nil, "invalid hex digit: 0x" .. a .. b
	end
	
	return 3, tonumber(a .. b, 16) -- ("xFF"):len() == 3
end

local literals = {
	n = "\n",
	r = "\r",
	t = "\t",
	v = "\v",
	b = "\b",
	a = "\a",
	f = "\f",
	x = parse_hex
}

local function parse_quotes(str, start)
	local literal = false
	local len = #str
	local ret = ""
	start = start + 1 -- remove the first quote
	
	local i = start
	while i <= len do
		local char = str:sub(i, i)
		
		if literal then
			local read, lit = 1, literals[char] or char
			
			if type(lit) == "function" then
				read, lit = lit(str, i, len)
				if read == nil then
					return nil, "failed to parse literal: " .. lit
				end
			end
			
			ret = ret .. lit
			i = i + (read - 1) -- increase the chars we've read
			literal = false
		else
			if char == '"' then
				return i, ret
			elseif char == '\\' then
				literal = true
			elseif char == "\n" or char == "\r" then
				return nil, "newline in string value"
			else
				ret = ret .. char
			end
		end
		i = i + 1
	end
	
	return nil, "" -- whoops, we got to the end, and no quote found...
end

-- Turn the string into some simple tokens, such as
-- string "abc"
-- string "def"
-- operator "{"
-- string "123"
-- newline
-- string "345"
-- operator "}"
---
-- which is equilivant to:
--"abc" "def"
--{
--	"123"
--	"345"
--}
local function tokenize(str)
	local pos, char = 1, nil
	local ret = {}
	local cur_line = 1
	local len = #str
	
	while pos <= len do
		char = str:sub(pos, pos)
		
		if char == "\n" then
			table.insert(ret, {type="newline", line=cur_line})
			cur_line = cur_line + 1
		elseif char == '"' then
			local endpos, val = parse_quotes(str, pos)
			if endpos == nil then
				return nil, string.format("%i: error parsing string literal: %s", cur_line, val)
			end
			pos = endpos
			table.insert(ret, {type="string", value=val, line=cur_line})
		elseif char == ' ' or char == '\t' or char == '\r' then -- do nothing with them
		else -- it must be an operator
			table.insert(ret, {type="operator", operator=char, line=cur_line})
		end
		
		pos = pos + 1
	end
	
	return ret
end

local function parse(tokens)
	local root_node = node.make(nil, "root")
	local current_node = root_node
	local new_node = nil
	
	local i = 1
	
	while i <= #tokens do
		local token = tokens[i]
		
		if token.type == "string" then
			local name, value = "", ""
			name = token.value
			
			if tokens[i + 1].type == "string" then
				value = tokens[i + 1].value
				i = i + 1
			end
			
			local newnode = current_node[name]
			newnode:set_value(value)
			
			new_node = newnode
		elseif token.type == "operator" then
			if token.operator == "{" then
				if not new_node then
					return nil, string.format("%i: no parent to assign children", token.line)
				end
				current_node = new_node
				new_node = nil
			elseif token.operator == "}" then
				current_node = current_node:parent()
				new_node = nil
				if current_node == nil then
					return nil, string.format("%i: unexpected '}'", token.line)
				end
			else
				return nil, string.format("%i: unknown operator '%s'", token.line, token.operator)
			end
		end
		
		i = i + 1
	end
	
	if current_node ~= root_node then
		return nil, string.format("%i: expected operator '}' at EOF", tokens[#tokens].line)
	end
	return root_node
end

function configor.loadstring(str)
	local tokens, err = tokenize(str)
	if tokens == nil then return nil, err end
	
	local ret, err = parse(tokens)
	
	return ret, err
end

function configor.loadfile(path, create)
	create = create ~= nil and create or true
	local file, err =  io.open(path, "r")
	
	-- attempt to make it
	if not file and create then
		local f = io.open(path, "w")
		if f then
			f:close()
			file, err =  io.open(path, "r")
		end
	end
	
	if not file then return nil, string.format("could not open file (%s)", err) end
	
	local contents = file:read("*a")
	return configor.loadstring(contents)
end

local replacements = {}

for i=0, 31 do -- hex
	replacements[string.char(i)] = string.format("\\x%x", i)
end
for i=127, 255 do -- hex
	replacements[string.char(i)] = string.format("\\x%x", i)
end

for k, v in pairs(literals) do repeat
	if type(v) == "function" then break end -- continue
	replacements[v] = "\\" .. k
until true end
replacements["'"] = "\\'"
replacements['"'] = '\\"'
replacements["	"] = "	" -- tab
replacements["\\"] = "\\\\" -- replace a backslash with 2 backslashes


local function quotify(str)
	local ret = ""
	
	for i=1, #str do
		local char = str:sub(i, i)
		if replacements[char] then char = replacements[char] end
		ret = ret .. char
	end
	
	return '"' .. ret .. '"'
end

local function serialize_nodes(nodes, depth)
	local tabs = string.rep("\t", depth)
	local ret = ""
	
	for k,node in pairs(nodes) do
		ret = ret .. tabs .. quotify(node:name())
		
		if node:data() ~= "" then
			ret = ret .. " " .. quotify(node:data()) .. "\n"
		else
			ret = ret .. "\n"
		end
		
		if node:has_children() then
			ret = ret .. tabs .. "{\n"
			ret = ret .. serialize_nodes(node:children(), depth + 1)
			ret = ret .. tabs .. "}\n"
		end
	end
	
	return ret
end

function configor.savestring(cfg) expects(node)
	return serialize_nodes(cfg:children(), 0)
end

function configor.savefile(cfg, path) expects(node)
	local file, err = io.open(path, "w")
	if not file then return nil, err end
	
	file:write(configor.savestring(cfg))
	file:close()
	return true
end

return configor
