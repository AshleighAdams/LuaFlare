
local httpstatus = require("httpstatus")
local template = include("template-error.lua")

local function on_error(why, request, response)
	print("error:", why.type, request:url())
end
hook.Add("Error", "log errors", on_error)

local function on_lua_error(err, trace, args)
	print("lua error:", err)--, trace)
end
hook.Add("LuaError", "log errors", on_lua_error)

local function basic_error(why, req, res)
	res:clear_content()
	
	local errcode = why.type or 500
	local errstr = string.format("%i %s", errcode, httpstatus.know_statuses[errcode] or "Unknown")
	local msg = why.message or req:url()
	
	template:make(errstr, errstr, msg).to_response(res)
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
	print(err, trace)
	
	local strvars = ""
	
	for k,v in pairs(vars) do
		strvars = strvars .. "(" .. type(v) .. ") " .. tostring(k) .. " = " .. tostring(v) .. "\n"
	end
	
	if res == nil or not res.clear then return end
	res:clear_content()
	res:set_status(500)
	
	local line_num = err:match("%.lua%:(%d+)%:")
	local line
	local code = ""
	
	if line_num ~= nil then
		local file = err:match("(.+):" .. line_num .. ": ")
		line_num = tonumber(line_num)
		
		line = line_from(file, line_num):gsub("\t", "")
	else
		line = hook.Call("LuaGetLine", err)
		
		if line == nil then
			line = "could not locate source"
		end
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
	
	local br_tag = tags.br
	if code == "" then br_tag = "" end
	
	local content =
	tags.div
	{
		tags.div {class = "box", style="margin-bottom: 5px;"}
		{
			err
		},
		tags.div {class = "box nowrap", style = "font-family: monospace; margin-bottom: 5px;"}
		{
			code,
			br_tag,
			line
		},
		tags.div {class = "box nowrap"}
		{
			trace
		}
	}
	
	template:make("500 Internal Server Error", "500 Internal Server Error", "", content).to_response(res)
end
hook.Add("LuaError", "basic error", basic_lua_error)
