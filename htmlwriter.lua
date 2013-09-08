
local generated_html = ""
function generate_html(tbl, depth, parent)
	tbl = tbl or {}
	depth = depth or 0
	local tabs = string.rep("\t", depth)
	local was_inline = false
	
	local len = generated_html:len()
	if generated_html:sub(len, len) ~= '\n' then
		tabs = " "
	end
	
	if type(tbl) == "function" then -- call the empty one
		tbl = tbl({})
	end
	
	if tbl.is_tag then
		local attributes = ""
		was_inline = tbl.tag_options.inline
		
		if tbl.extra and type(tbl.extra) == "string" then
			attributes = " " .. tbl.extra
		elseif tbl.extra and type(tbl.extra) == "table" then
			for k,v in pairs(tbl.extra) do
				attributes = " " .. k .. "=" .. "\"" .. v .. "\""
			end
		end
		
		local endbit = ">"
		if tbl.tag_options.empty_element then
			endbit = " />"
		end
		
		generated_html = generated_html .. tabs .. "<" .. tbl.name .. attributes .. endbit
		
		if not tbl.tag_options.inline then
			generated_html = generated_html .. "\n"
		end
		
		if not tbl.tag_options.empty_element then
			if tbl.children then
				for k,v in pairs(tbl.children) do
					generate_html(v, depth + 1, tbl)
				end
			end
		
			if not tbl.tag_options.inline then
				local len = generated_html:len()
				if generated_html:sub(len, len) ~= '\n' then
					generated_html = generated_html .. "\n"
				end
				generated_html = generated_html .. tabs
			end
		
			generated_html = generated_html .. "</" .. tbl.name .. ">" .. "\n"
		end
	else
		if parent.tag_options.inline then
			generated_html = generated_html .. tostring(tbl)
		else
			if was_inline then
				generated_html = generated_html .. "\n"
			end
			
			generated_html = generated_html .. tabs .. tostring(tbl) .. "\n"
		end
	end
	
	if depth == 0 then
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

function generate_tag(name, options)
	options = options or {}
	
	_G[name] = function(tbl)
		if type(tbl) ~= "table" or is_extra_data(tbl) then
			return function(...)
				local ret = _G[name](...)
				
				ret.extra = tbl
				return ret
			end
		end
				
		local node = {is_tag = true, name = name, children = tbl, tag_options = options}
		node.to_html = function() return generate_html(node) end
		node.to_response = function() error("notimpl") end
		node.print = function() print(generate_html(node)) end
		
		return node
	end
end

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
