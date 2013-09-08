reqs.AddPattern("*", "/profile/(%d+)", function(request, response, id)
	id = tonumber(id)
	
	-- error is on purpose
	response:apend("Hello, you requested the profile id " .. id .. tostring(request))
end)

local template = tags.html
{
	tags.head
	{
		tags.title { tags.SECTION },
		tags.style
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
			}
			div.nowrap {
				white-space: nowrap;
			}
			]]
		}
	},
	tags.body
	{
		tags.div {class = "bg_wrapper"}
		{
			tags.div {class = "wrapper"}
			{
				tags.p {style = "font-size: 22; margin-top: 0px; border-bottom: 1px solid #dddddd"}
				{
					tags.SECTION
				},
				tags.SECTION
			}
		}
	}
}

local last_runlua = ""
local function run_lua_page(req, res)
	local content = tags.div
	{
		tags.p { "Run Lua code:" },
		tags.form {method = "get", action = "/runlua"}
		{
			tags.SECTION,
			tags.input{type = "submit"}
		},
		tags.div {class = "box nowrap"}
		{
			tags.SECTION
		}
	}
	
	local title = "Run Lua"
	local lua = req.parsed_url.params.lua or [[
function test()
    print("hi")
end

test()

return 0, "abc"
	]]
	
	template.to_response(res, 0) -- <title>
	res:append(title)
	template.to_response(res, 1) -- header
	res:append(title)
	template.to_response(res, 2) -- content
	
		content.to_response(res, 0)
		res:append("<textarea name='lua' rows=20 cols=68>\n")
		res:append(html_escape(lua, false))
		res:append("</textarea>\n")
		
		content.to_response(res, 1)
			-- output
			last_runlua = lua
			local func = loadstring(lua, "runlua")
			local prefix = ""
			for k,v in pairs({func()}) do
				res:append(html_escape(prefix .. to_lua_value(v)))
				prefix = ", "
			end
		content.to_response(res, 2)
		
	template.to_response(res, 3)
end
reqs.AddPattern("*", "/runlua", run_lua_page)

hook.Add("LuaGetLine", "locate runstring", function(err)
	local line_num = err:match('%[string "runlua"]:(%d+): ')
	
	if line_num then
		line_num = tonumber(line_num)
		local line = ""
		
		for i=1, last_runlua:len() do
			local char = last_runlua:sub(i, i)
			
			if char == '\n' then
				line_num = line_num - 1
				if line_num == 0 then break end
				line = ""
			else
				line = line .. char
			end
		end
		
		return line
	end
end)
