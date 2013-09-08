
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
				width: 500px;
				margin: 0px auto;
				margin-top: 100px;
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

hook.Add("LuaError", "basic error", function(err, trace, vars, args)
	local req = args[1]
	local res = args[2]
	
	trace = trace or "stack trace unavailble"
	local strvars = ""
	
	for k,v in pairs(vars) do
		strvars = strvars .. "(" .. type(v) .. ") " .. tostring(k) .. " = " .. tostring(v) .. "\n<br/>"
	end
	
	res:clear()
	res:set_status(501)
	
	local content =
	div
	{
		p { "A Lua error was encountered while trying to process your request!" },
		div {class = "box", style="margin-bottom: 5px;"}
		{
			'while requesting "' .. req.full_url .. '":', br,
			err
		},
		div {class = "box", style="margin-bottom: 5px;"}
		{
			"local vars:", br, strvars
		},
		div {class = "box"}
		{
			(trace:gsub("\n", "<br />\n"))
		}
	}
	
	error_template.to_response(res, 0)
	content.to_response(res)
	error_template.to_response(res, 1)
end)
