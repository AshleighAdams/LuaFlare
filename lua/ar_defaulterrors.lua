local function on_error(why, request, response)
	response:set_status(why.type)
	print("error:", why.type, request:url())
end
hook.Add("Error", "log errors", on_error)

local function on_lua_error(err, trace, args)
	print("lua error:", err)--, trace)
end
hook.Add("LuaError", "log errors", on_lua_error)

local error_type_to_str = {
	[401] = "Not Authorized",
	[404] = "Resource Not Found",
	[501] = "Internal Server Error"
}

error_template = tags.html
{
	tags.head
	{
		tags.title { "Error" },
		tags.link {rel = "stylesheet", type = "text/css", href = "/error_style.css"}
	},
	tags.body
	{
		tags.div {class = "bg_wrapper"}
		{
			tags.div {class = "wrapper"}
			{
				tags.p {style = "font-size: 22; margin-top: 0px; border-bottom: 1px solid #dddddd"} {"Error!"},
				tags.SECTION
			}
		},
		tags.div {class = "footer"}
		{
			string.format("pid: %i", script.pid())
		}
	}
}

local function basic_error(why, req, res)
	res:set_status(why.type)
	res:clear()
	
	local content = tags.div
	{
		tags.p { "There was an error while processing your request!" },
		tags.div {class = "box"}
		{
			"while requesting",
			tags.code
			{
				req:url()
			},
			" an error of type ",
			tags.code
			{
				tostring(why.type) .. " (" .. (error_type_to_str[why.type] or "unknown") .. ")"
			},
			" was encountered",
			(function()
				if why.message then
					return tags.code { "\n\n" .. why.message }
				end
			end)()
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
	print(err, trace)
	
	local strvars = ""
	
	for k,v in pairs(vars) do
		strvars = strvars .. "(" .. type(v) .. ") " .. tostring(k) .. " = " .. tostring(v) .. "\n"
	end
	
	if res == nil or not res.clear then return end
	res:clear()
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
		tags.p { "A Lua error was encountered while trying to process your request!" },
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
	
	error_template.to_response(res, 0)
	content.to_response(res)
	error_template.to_response(res, 1)
end
hook.Add("LuaError", "basic error", basic_lua_error)
