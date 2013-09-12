reqs = {}
reqs.PatternsRegistered = {}
reqs.FilesRegistered = {}

local function valid_host(target, what)
	target = target or "main"
	return string.match(target, what) ~= nil
end

local function generate_host_patern(what) -- TODO: use pattern_escape, can't replace the *
	local pattern = what
	
	-- TODO: should these even be here? other than the . and * replacement
	pattern = string.gsub(pattern, "%%", "%%%") -- this must be first...	
	pattern = string.gsub(pattern, "%.", "%%.") -- escape them
	pattern = string.gsub(pattern, "%(", "%%(")
	pattern = string.gsub(pattern, "%)", "%%)")
	pattern = string.gsub(pattern, "%+", "%%+")

	-- now, allow things like *domain.net, or *.domain.net, *domain.net*
	pattern = string.gsub(pattern, "*", ".+")
	
	return pattern
end

local function generate_resource_patern(pattern)
	pattern = string.gsub(pattern, "*", ".+")
	return "__start__" .. pattern .. "__end__"
end

reqs.AddPattern = function(host, url, func)
	host = generate_host_patern(host)
	url = generate_resource_patern(url)
	
	for k, v in pairs(reqs.PatternsRegistered) do -- already exists, overwrite it and warn
		if v.host == host and v.url == url then
			v.func = func
			return
		end
	end
	
	table.insert(reqs.PatternsRegistered, {host = host, url = url, func = func})
end

reqs.OnRequest = function(request, response)
	local hits = {}
	local req_url = "__start__" .. request:url() .. "__end__"
	
	for k,v in ipairs(reqs.PatternsRegistered) do
		if valid_host(request:headers().Host, v.host) then
			local pattern = v.url -- there is a hack, so we detect the start end end of the string (not partial)
			local res = { string.match(req_url, pattern) }
			
			if #res ~= 0 then
				table.insert(hits, {hook = v, res = res})
			end
		end
	end
	
	if #hits == 0 then
		hook.Call("Error", {type = 404}, request, response)
	elseif #hits ~= 1 then
		hook.Call("Error", {type = 501, hits = hits}, request, response)
	else
		hits[1].hook.func(request, response, unpack(hits[1].res))
	end
end
hook.Add("Request", "default handler", reqs.OnRequest)



hook.Add("Error", "basic error", function(why, req, res)
	res:set_status(why.type)
	res:clear()
	res:append(
		html
		{
			head
			{
				title { "Error: " .. tostring(why.type) },
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
						background-image: ]]..lua_icon_base64..[[;
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
						p { "There was an error wile processing your request!" },
						div {class = "box"}
						{
							"while requesting \"" .. req.full_url .. " an error of type " .. tostring(why.type) .. " (" .. (error_type_to_str[why.type] or "unknown") .. ") was encountered"
						}
					}
				}
			}
		}.to_html()
	)
end)

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
	
	res:append(
		html
		{
			head
			{
				title { "Lua Error" },
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
						background-image: ]]..lua_icon_base64..[[;
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
				}
			}
		}.to_html()
	)
end)
