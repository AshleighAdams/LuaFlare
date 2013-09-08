tags = {}

local generated_html = ""
function generate_html(first, tbl, depth, parent, section, current_section)
	tbl = tbl or {}
	depth = depth or 0
	current_section = current_section or {0} -- references
	section = section or 0
	
	if tbl == nil then
		error("tbl is nil")
	end
	
	local tabs = string.rep("\t", depth)
	local was_inline = false
	
	--local len = generated_html:len()
	--if generated_html:sub(len, len) ~= '\n' then
	--	tabs = ""
	--end
	
	if type(tbl) == "function" then -- call the empty one
		tbl = tbl({})
	end
	
	if type(tbl) == "table" and tbl.is_tag and tbl.tag_options.section_marker then
		current_section[1] = current_section[1] + 1
	elseif type(tbl) == "table" and  tbl.is_tag then
		local attributes = ""
		was_inline = tbl.tag_options.inline
		
		if tbl.extra and type(tbl.extra) == "string" then
			attributes = " " .. tbl.extra
		elseif tbl.extra and type(tbl.extra) == "table" then
			for k,v in pairs(tbl.extra) do
				attributes = attributes .. " " .. k .. "=" .. "\"" .. v .. "\""
			end
		end
		
		local endbit = ">"
		if tbl.tag_options.empty_element then
			endbit = " />"
		end
		
		if section == current_section[1] then
			generated_html = generated_html .. tabs .. "<" .. tbl.name .. attributes .. endbit
		end
		
		if not tbl.tag_options.inline and section == current_section[1] then
			generated_html = generated_html .. "\n"
		end
		
		if not tbl.tag_options.empty_element then
			if tbl.children then
				for k,v in pairs(tbl.children) do
					generate_html(false, v, depth + 1, tbl, section, current_section)
				end
			end
		
			if not tbl.tag_options.inline and section == current_section[1] then
				local len = generated_html:len()
				if generated_html:sub(len, len) ~= '\n' then
					generated_html = generated_html .. "\n"
				end
				generated_html = generated_html .. tabs
			end
			
			if section == current_section[1] then
				generated_html = generated_html .. "</" .. tbl.name .. ">" .. "\n"
			end
		end
	elseif type(tbl) == "table" and section == current_section[1] then
		for k,v in pairs(tbl) do
			generate_html(false, v, depth + 1, parent, section, current_section)
		end
	elseif section == current_section[1] then
		local whattowrite = tostring(tbl)
		local in_tabs = nil
		
		for match in whattowrite:gmatch("\n([\t]*)") do
			if in_tabs == nil or match:len() < in_tabs:len() then
				in_tabs = match
			end
		end
		
		if in_tabs ~= nil then
			whattowrite = whattowrite:gsub(in_tabs, "")
			whattowrite = whattowrite:gsub("\n", "\n" .. tabs)
		end
		
		--whattowrite = html_escape(whattowrite)
		
		if not first and parent.tag_options.inline then
			generated_html = generated_html .. whattowrite
		else
			if was_inline then
				generated_html = generated_html .. "\n"
			end
			
			generated_html = generated_html .. tabs .. whattowrite .. "\n"
		end
	end
	
	if first then
		local ret = generated_html
		generated_html = ""
		return ret
	end
end

function is_extra_data(tbl) -- extra data must use {key=value} syntax at least once, and not {value}
	local count = 0
	for k,v in pairs(tbl) do
		count = count + 1
	end
	
	return count ~= #tbl
end

function last_of(str, pattern)
	if (pattern == '' or pattern == nil) then
		return nil
	end

	local position = string.find(str, pattern, 1)
	local previous = nil

	while (position ~= nil) do
		previous = position
		position = string.find(str, pattern, previous + 1)
	end

	return previous
end

function end_tab_depth(str)
	local lastof = (last_of(str, "\n.+") or 0) + 1
	local lastline = str:sub(lastof)
	local tabs = 0
	
	for i=1, lastline:len() do
		if string.byte(lastline:sub(i)) ~= 9 then break end
		
		tabs = tabs + 1
	end
	
	return tabs
end

function start_tab_depth(str)
	local depth = 0
	
	for i=2, str:len() do
		if str:sub(i,i):byte() ~= 9 then break end
		depth = depth + 1
	end
	
	if depth ~= 0 then return depth + 1 end
	return depth
end

function generate_tag(name, options)
	options = options or {}
	
	tags[name] = function(tbl)
		if type(tbl) ~= "table" or is_extra_data(tbl) then
			return function(...)
				local ret = tags[name](...)
				
				ret.extra = tbl
				return ret
			end
		end
				
		local node = {is_tag = true, name = name, children = tbl, tag_options = options}
		
		node.to_html = function(section) return generate_html(true, node, nil, nil, section) end
		node.print = function(section) print(generate_html(true, node, nil, nil, section)) end
		node.to_response = function(response, section)
			local gen = generate_html(true, node, nil, nil, section)
			
			local at_tabs = end_tab_depth(response.response_text)
			local start_depth = start_tab_depth(gen)
			
			local extra_tabs = string.rep("\t", at_tabs - start_depth)
			
			gen = extra_tabs .. gen:gsub("\n", "\n" .. extra_tabs)
			response:append(gen)
		end
		
		return node
	end
end

generate_tag("SECTION", {section_marker = true})
generate_tag("html")
generate_tag("head")
generate_tag("body")
generate_tag("script")
generate_tag("style")
generate_tag("link", {empty_element = true})
generate_tag("title", {inline = true})
generate_tag("div")
generate_tag("br", {inline = true, empty_element = true})
generate_tag("img", {empty_element = true})
generate_tag("a", {inline = true})
generate_tag("p", {inline = true})
generate_tag("span", {inline = true})
generate_tag("code", {inline = true})
generate_tag("pre")
generate_tag("table")
generate_tag("tr")
generate_tag("tc")
generate_tag("form")
generate_tag("input")
generate_tag("textarea")

--[[

html
{
	head
	{
		title
		{
			"Hello, world"
		}
	},
	body
	{
		div {class = "test"}
		{
			"This is a really nice generation thingy",
			br, br,
			"Do you like my logo?",
			br,
			img {src = "/logo.png"}
		}
	}
}.print()

produces:

<html>
	<head>
		<title>Hello, world</title>
	</head>
	<body>
		<div class="test">
			This is a really nice generation thingy
			<br /> <br /> Do you like my logo?
			<br /> <img src="/logo.png" />
		</div>
	</body>
</html>


]]
