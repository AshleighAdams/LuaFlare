local escape = require("luaserver.util.escape")

local tags = {}

-- meh, doesn't change view, but it produces nicer code
local allow_inline = false
local generated_html = ""

local attribute_escapers = {}

local function default_attribute_escaper(val)
	return "\"" .. escape.attribute(val) .. "\""
end

--attribute_escapers.href = url_attribute_escaper
--attribute_escapers.src = url_attribute_escaper

local function generate_html(first, tbl, depth, parent, section, state)
	tbl = tbl or {}
	depth = depth or 0
	state = state or {current_section = 0, escape_this = true} -- references
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
		state.current_section = state.current_section + 1
	elseif type(tbl) == "table" and tbl.is_tag and tbl.tag_options.noescape then
		state.escape_this = false
	elseif type(tbl) == "table" and  tbl.is_tag then
		if state.escape_this == false then
			error("Attempting to not escape a tag element (are you sure you have the tags.NOESCAPE in the right place?")
		end
		
		local attributes = ""
		was_inline = tbl.tag_options.inline and allow_inline 
		
		if tbl.extra and type(tbl.extra) == "string" then
			attributes = " " .. tbl.extra
		elseif tbl.extra and type(tbl.extra) == "table" then
			for k,v in pairs(tbl.extra) do
				local attrb_escaper = attribute_escapers[k:lower()] or default_attribute_escaper
				attributes = attributes .. " " .. k .. "=" .. attrb_escaper(v)
			end
		end
		
		local endbit = ">"
		if tbl.tag_options.empty_element then
			endbit = " />"
		end
		
		if section == state.current_section then
			if tbl.tag_options.pre_text then
				generated_html = tabs .. tbl.tag_options.pre_text:gsub("\n", "\n" .. tabs) .. generated_html
			end
			generated_html = generated_html .. tabs .. "<" .. tbl.name .. attributes .. endbit
		end
		
		if not (tbl.tag_options.inline and allow_inline) and section == state.current_section then
			generated_html = generated_html .. "\n"
		end
		
		if not tbl.tag_options.empty_element then
			if tbl.children then
				for k,v in pairs(tbl.children) do
					generate_html(false, v, depth + 1, tbl, section, state)
				end
			end
		
			if not (tbl.tag_options.inline and allow_inline) and section == state.current_section then
				local len = generated_html:len()
				if generated_html:sub(len, len) ~= '\n' then
					generated_html = generated_html .. "\n"
				end
				generated_html = generated_html .. tabs
			end
			
			if section == state.current_section then
				generated_html = generated_html .. "</" .. tbl.name .. ">" .. "\n"
			end
		end
	elseif type(tbl) == "table" and section == state.current_section then
		for k,v in pairs(tbl) do
			generate_html(false, v, depth + 1, parent, section, state)
		end
	elseif section == state.current_section then
		local whattowrite = tostring(tbl)
		local in_tabs = nil
		
		for match in whattowrite:gmatch("\n([\t]*)") do
			if in_tabs == nil or match:len() < in_tabs:len() then
				in_tabs = match
			end
		end
		
		-- TODO: Should this be here?
		if state.escape_this then
			local func = parent and parent.tag_options.escape_function or escape.html
			whattowrite = func(whattowrite)
		else
			state.escape_this = true -- re-enable escaping
		end
		
		if in_tabs ~= nil then
			whattowrite = whattowrite:gsub(in_tabs, "")
			whattowrite = whattowrite:gsub("\n", "\n" .. tabs)
		end
			
		if not first and (parent.tag_options.inline and allow_inline) then
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

local function is_extra_data(tbl) -- extra data must use {key=value} syntax at least once, and not {value}
	local count = 0
	for k,v in pairs(tbl) do
		count = count + 1
	end
	
	return count ~= #tbl
end

local function last_of(str, pattern)
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

local function end_tab_depth(str)
	local lastof = (last_of(str, "\n.+") or 0) + 1
	local lastline = str:sub(lastof)
	local tabs = 0
	
	for i=1, lastline:len() do
		if string.byte(lastline:sub(i)) ~= 9 then break end
		
		tabs = tabs + 1
	end
	
	return tabs
end

local function start_tab_depth(str)
	local depth = 0
	
	for i=2, str:len() do
		if str:sub(i,i):byte() ~= 9 then break end
		depth = depth + 1
	end
	
	if depth ~= 0 then return depth + 1 end
	return depth
end

local function generate_tag(name, options)
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
			
			local at_tabs = end_tab_depth(response._reply)
			local start_depth = start_tab_depth(gen)
			
			local extra_tabs = string.rep("\t", at_tabs - start_depth)
			
			gen = extra_tabs .. gen:gsub("\n", "\n" .. extra_tabs)
			response:append(gen)
		end
		
		return node
	end
end

generate_tag("SECTION", {section_marker = true})
generate_tag("NOESCAPE", {noescape = true})
generate_tag("html", {pre_text = "<!DOCTYPE html>\n"})
generate_tag("head")
generate_tag("body")
generate_tag("script", {escape_function = escape.striptags})
generate_tag("style", {escape_function = escape.striptags})
generate_tag("link", {empty_element = true})
generate_tag("meta", {empty_element = true})
generate_tag("title", {inline = true})
generate_tag("div")
generate_tag("header")
generate_tag("main")
generate_tag("footer")
generate_tag("br", {inline = true, empty_element = true})
generate_tag("img", {empty_element = true})
generate_tag("image", {empty_element = true})
generate_tag("a", {inline = true})
generate_tag("p", {inline = true})
generate_tag("span", {inline = true})
generate_tag("code", {inline = true})
generate_tag("h1", {inline = true})
generate_tag("h2", {inline = true})
generate_tag("h3", {inline = true})
generate_tag("h4", {inline = true})
generate_tag("h5", {inline = true})
generate_tag("h6", {inline = true})
generate_tag("b", {inline = true})
generate_tag("center", {inline = true})
generate_tag("i", {inline = true})
generate_tag("u", {inline = true})
generate_tag("pre")
generate_tag("table")
generate_tag("ul")
generate_tag("li", {inline = true})
generate_tag("tr")
generate_tag("td")
generate_tag("tc")
generate_tag("form")
generate_tag("input")
generate_tag("textarea")


return tags
