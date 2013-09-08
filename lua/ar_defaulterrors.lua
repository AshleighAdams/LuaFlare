
local error_type_to_str = {
	[401] = "Not Authorized",
	[404] = "Resource Not Found",
	[501] = "Internal Server Error"
}

error_template = html
{
	head
	{
		title { "Error" },
		style
		{
			[[
			body {
				background-color: #DDDDDD;
				font-family: Helvetica, Arial, sans-serif;
			}
			div.bg_wrapper
			{
				width: 600px;
				margin: 0px auto;
				margin-top: 50px;
				background-color: #ffffff;
				background-image: url(http://lua-users.org/files/wiki_insecure/lua-icons-png/lua-256x256.png);
				background-repeat: no-repeat;
				background-position: center center;
				box-shadow: 0px 0px 50px #888888;
			}
			div.wrapper {
				
				background-color: rgba(255, 255, 255, 0.95);
				#border-radius: 4px;
				padding: 15px;
			}
			div.box {
				background-color: rgba(240, 240, 255, 0.5);
				border: 1px solid #ddddff;
				padding: 5px;
				overflow: auto;
				overflow-y: hidden;
				white-space: nowrap;
			}
			]]
		}
	},
	body
	{
		div {class = "bg_wrapper"}
		{
			div {class = "wrapper"}
			{
				p {style = "font-size: 22; margin-top: 0px; border-bottom: 1px solid #dddddd"} {"Error!"},
				SECTION
			}
		}
	}
}

local function basic_error(why, req, res)
	res:set_status(why.type)
	res:clear()
	
	local content = div
	{
		p { "There was an error while processing your request!" },
		div {class = "box"}
		{
			"while requesting \"" .. req.full_url .. " an error of type " .. tostring(why.type) .. " (" .. (error_type_to_str[why.type] or "unknown") .. ") was encountered"
		}
	}
	
	
	
	error_template.to_response(res, 0)
	content.to_response(res)
	error_template.to_response(res, 1)
end
hook.Add("Error", "basic error", basic_error)

function line_from(file, line_targ)
	for line in io.lines(file) do 
		line_targ = line_targ - 1
		if line_targ == 0 then
			return line
		end
	end
	return ""
end

local function basic_lua_error(err, trace, vars, args)
	local req = args[1]
	local res = args[2]
	
	trace = trace or "stack trace unavailble"
	local strvars = ""
	
	for k,v in pairs(vars) do
		strvars = strvars .. "(" .. type(v) .. ") " .. tostring(k) .. " = " .. tostring(v) .. "\n"
	end
	
	res:clear()
	res:set_status(501)
	
	local line_num = tonumber(err:match("%.lua%:(%d+)%:"))
	local file = err:match("(.+):" .. tostring(line_num) .. ": ")
	
	local line = line_from(file, line_num)
	local code = ""
	
	local function to_lua_value(var)
		local val = tostring(var)
		
		if type(var) == "string" then
			val = val:gsub("\n", "\\n")
			val = val:gsub("\t", "\\t")
			val = val:gsub("\r", "\\r")
			val = val:gsub("\"", "\\\"")
			
			val = "\"" .. val .. "\""
		end
		
		return val
	end
	
	local function is_empty_tbl(tbl)
		for k,v in pairs(tbl) do
			return false
		end
		return true
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
	
	local function to_lua_table(tbl, depth, done)
		if is_empty_tbl(tbl) then return "{}" end
		
		depth = depth or 1
		done = done or {}
		
		local ret = "{\n"
		local tabs = string.rep("\t", depth)
		
		for k, v in pairs(tbl) do
			ret = ret .. tabs .. to_lua_table_key(k) .. " = "
			
			if type(v) ~= "table" or done[v] then
				ret = ret .. to_lua_value(v)
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
	
	local done = {}
	for varname in line:gmatch("[A-z_][A-z0-9]*") do
		if vars[varname] ~= nil and not done[varname] then
			done[varname] = true
			
			local val = to_lua_value(vars[varname])
			local typ = type(vars[varname])
			
			if typ == "table" then
				val = to_lua_table(vars[varname])
			end
			
			code = code .. "local " .. varname .. " = " .. val .. "\n"
		end
	end
	
	local content =
	div
	{
		p { "A Lua error was encountered while trying to process your request!" },
		div {class = "box", style="margin-bottom: 5px;"}
		{
			html_escape(err)
		},
		div {class = "box", style = "font-family: monospace; margin-bottom: 5px;"}
		{
			html_escape(code),
			br,
			line
		},
		div {class = "box"}
		{
			html_escape(trace)
		}
	}
	
	error_template.to_response(res, 0)
	content.to_response(res)
	error_template.to_response(res, 1)
end
hook.Add("LuaError", "basic error", basic_lua_error)
