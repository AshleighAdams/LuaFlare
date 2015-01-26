#!/usr/bin/lua

local input = assert(arg[1])
local output = assert(arg[2])
local domain = arg[3] or "us"
local multi = tonumber(arg[4]) or 1

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
		  rect.box   { fill: rgb(240,240,240); stroke: rgb(192,192,192); }
		  line       { stroke: rgb(64,64,64); stroke-width: 1; }
		  line.start { stroke: rgb(64,255,64); stroke-width: 1; }
		  line.end   { stroke: rgb(255,64,64); stroke-width: 1; }
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

for line in io.lines(input) do
	if line == "SECT" then
	elseif line == "SECT_END" then
	else
		local t, why, name, where, args = line:match("([^\t]+).-([+-]).-([^\t]+).-([^\t]+).-([^\t]-)$")
		t = t * domain.multi * multi -- us domain
		
		local file, line = where:match("([^/]+)%.lua.-:(%d+)")
		if file then
			line = line or ""
			name = file..":"..line.." "..name
		end
		
		if not start then
			start = t
		end
		t = t - start
		
		if why == "+" then
			table.insert(stack, {
				entered = t,
				name = name,
				source = where,
				args = args
			})
			print((" "):rep(#stack)..name, args)
		elseif why == "-" then
			local info = table.remove(stack, #stack)
			
			if info then
				--print(#stack, info.name, name)
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
		else
			error()
		end
	end
	
end

print("stack: " .. #stack)

width = width + 401
height = height + 100

local x = width - bar_height
for y = 100, height, 100 do
	
	local str = string.format("%s%s", tostring(y / (100 * multi)), domain.units)
	table.insert(content, ([[<text transform="translate(%d,%d) rotate(0)" class="%s" x="0px" y="0px">%s</text>]]):format(x, y, "t", str) )
end

--table.insert(content, ([[<text transform="translate(%d,%d) rotate(0)" class="%s" x="0px" y="0px">%s</text>]]):format(x, y + 5, class, str) )

--do return end

local f = io.open(output, "w")
f:write( header:gsub("%$width", width):gsub("%$height", height):gsub("$barheight", bar_height) )
f:write( table.concat(content, "\n"):gsub("$barheight", bar_height) )
f:write( footer )
f:close()










