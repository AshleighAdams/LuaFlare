#!/usr/bin/lua

local input = assert(arg[1])
local output = assert(arg[2])
local scale = arg[3] or "1us"

local multi, domain = scale:match("([%d%.]+)([^ ]+)")

if not multi then
	multi = 1
	domain = scale
else
	multi = 1.0 / multi
end

local header = [=[
<?xml version="1.0" standalone="no"?>
<!DOCTYPE svg PUBLIC "-//W3C//DTD SVG 1.1//EN" "http://www.w3.org/Graphics/SVG/1.1/DTD/svg11.dtd">
<svg width="$widthpx" height="$heightpx" version="1.1" xmlns="http://www.w3.org/2000/svg">

	<defs>
	  <style type="text/css">
		<![CDATA[
		  rect       { stroke-width: 1; stroke-opacity: 0; }
		  rect.lua   { fill: rgb(150,150,150); fill-opacity: 0.5; }
		  rect.c     { fill: rgb(200,150,150); fill-opacity: 0.5; }
		  rect.tail  { fill: rgb(150,150,200); }
		  rect.box   { fill: rgb(240,240,240); stroke: rgb(192,192,192); }
		  line.kb    { stroke: rgb(150,255,150); stroke-width: 2; stroke-opacity: 0.5; }
		  text       { font-family: Verdana, Helvetica; font-size: 10px; }
		  text.left  { font-family: Verdana, Helvetica; font-size: 10px; text-anchor: start; }
		  text.right { font-family: Verdana, Helvetica; font-size: 10px; text-anchor: end; }
		  text.sec   { font-size: 10px; }
		]]>
	   </style>
	   
		<pattern id="small-grid" width="$barheight" height="10" patternUnits="userSpaceOnUse">
			<path d="M $barheight 0 L 0 0 0 10" fill="none" stroke="gray" stroke-width="0.5"/>
		</pattern>
			<pattern id="grid" width="100" height="100" patternUnits="userSpaceOnUse">
			<rect width="100" height="100" fill="url(#small-grid)"/>
			<path d="M 100 0 L 0 0 0 0" fill="none" stroke="gray" stroke-width="1"/>
		</pattern>
	</defs>

	<rect width="100%" height="100%" fill="url(#grid)" />
	
	<rect class="lua" x="350px" y="10px" width="$barheight" height="10px"/>
	<text transform="translate(%d,%d) rotate(0)" class="lua" x="405px" y="19px">Lua</text>
	
	<rect class="lua tail" x="350px" y="20px" width="$barheight" height="10px"/>
	<text transform="translate(%d,%d) rotate(0)" class="lua" x="405px" y="29px">Lua - Tail Call</text>
	
	<rect class="c" x="350px" y="30px" width="$barheight" height="10px"/>
	<text transform="translate(%d,%d) rotate(0)" class="c" x="405px" y="39px">C</text>
]=]

local footer = [=[
</svg>
]=]

local content = {}
local width, height = 0, 0

local bar_height = 50

local stack = {}
local start = nil
local lastx = 0

local domains = {
	s  = {units = "s",  multi = 1},
	ms = {units = "ms", multi = 1 * 1000},
	us = {units = "us", multi = 1 * 1000 * 1000},
	ns = {units = "ns", multi = 1 * 1000 * 1000 * 1000},
}
domain = assert(domains[domain], "unknown domain: " .. domain)

local mem_usage = {}
local func_times = {}

for line in io.lines(input) do
	if line == "SECT" then
	elseif line == "SECT_END" then
	else
		local t, mem, why, name, where, args = line:match("([^\t]+).-([^\t]+).-([+-~]).-([^\t]+).-([^\t]+).-([^\t]-)$")
		t = t * domain.multi * multi -- us domain
		mem = tonumber(mem)
				
		args = args:gsub("&#(%d+);", "&amp;#%1;")
				
		local file, line = where:match("([^/]+)%.lua.-:(%d+)")
		if file then
			line = line or ""
			name = file..":"..line.." "..name
		end
		
		if not start then
			start = t
		end
		t = t - start
		
		table.insert(mem_usage, {t=t,kb=mem})
		
		if why == "+" or why == "~" then
			table.insert(stack, {
				entered = t,
				name = name,
				source = where,
				args = args,
				tail = why == "~"
			})
			print((" "):rep(#stack)..name, args)
		elseif why == "-" then
			-- tail calls don't have their own return, obvsly, so make sure you follow the tail
			
			local function finalize_info(info)
				if not info then return end
				
				local y = info.entered
				local x = #stack * bar_height
				local h = (t - info.entered)
				
				if y + h > height then
					height = y + h --bar_height * 2
				end
				
				if x + bar_height*2 > width then
					width = x + bar_height*2
				end
				
				local is_c = info.source == "[C]:-1" and where == "[C]:-1"
				local class = is_c and "c" or "lua"
				
				if info.tail then
					class = class .. " tail"
				end
				
				func_times[name] = (func_times[name] or 0) + h
				table.insert(content, ([[<rect class="%s" x="%fpx" y="%dpx" width="$barheight" height="%f"/>]]):format(class, x, y, h) )
				if not is_c or true then
					lastx = x
					local str = info.name
					local extra = ""
					if info.name ~= name then
						str = str .. " or " .. name
					end
					
					if info.args ~= "" then
						extra = " (" .. info.args .. ")"
					end
					table.insert(content, ([[<text transform="translate(%d,%d) rotate(0)" class="%s" x="0px" y="0px">%s%s</text>]]):format(x, y + 9, class, str, extra) )
					
					if args ~= "" then
						extra = " return " .. args
						str = ""
						table.insert(content, ([[<text transform="translate(%d,%d) rotate(0)" class="%s" x="0px" y="0px">%s%s</text>]]):format(x, y + h, class, str, extra) )
					end
				end
			end
			
			
			while true do
				local info = table.remove(stack, #stack)
					finalize_info(info)
				if not info or not info.tail then break end
			end
			
		else
			error()
		end
	end
	
end

print("stack: " .. #stack)

local pre_content = {}

width = width + 401
height = height + 100

local x = width - bar_height
for y = 100, height, 100 do
	
	local str = string.format("%s%s", tostring(y / (100 * multi)), domain.units)
	table.insert(content, ([[<text transform="translate(%d,%d) rotate(0)" class="%s" x="0px" y="0px">%s</text>]]):format(x, y, "t", str) )
end

do
	local min, max = math.huge, 0
	for k,v in ipairs(mem_usage) do
		local t, kb = v.t, v.kb
		
		if kb < min then
			min = kb
		elseif kb > max then
			max = kb
		end
	end
	
	table.insert(pre_content, ([[<text class="left" x="0%%" y="10px">%.2f KB</text>]])
		:format(min) )
	table.insert(pre_content, ([[<text class="right" x="100%%" y="10px">%.2f KB</text>]])
		:format(max) )
		
	
	for k = 1, #mem_usage - 1 do
		local a = mem_usage[k]
		local b = mem_usage[k + 1]
		
		local kb_a = (a.kb - min) / (max - min) * 100
		local kb_b = (b.kb - min) / (max - min) * 100
		
		local x1 = kb_a
		local y1 = a.t
		local x2 = kb_b
		local y2 = b.t
		
		table.insert(pre_content, ([[<line class="kb" x1="%f%%" y1="%fpx" x2="%f%%" y2="%fpx" />]])
			:format(x1, y1, x2, y2))
		
	end
end

local sorted = {}

for k,v in pairs(func_times) do
	table.insert(sorted, {name = k, t = v})
end

table.sort(sorted, function(a, b) return a.t > b .t end)

for k,v in ipairs(sorted) do
	print(v.name, v.t)
end

--table.insert(content, ([[<text transform="translate(%d,%d) rotate(0)" class="%s" x="0px" y="0px">%s</text>]]):format(x, y + 5, class, str) )

--do return end

local f = io.open(output, "w")
f:write( header:gsub("%$width", width):gsub("%$height", height):gsub("$barheight", bar_height) )
f:write( table.concat(pre_content, "\n"):gsub("$barheight", bar_height) )
f:write( table.concat(content, "\n"):gsub("$barheight", bar_height) )
f:write( footer )
f:close()










