#!/usr/bin/env lua

local lfs = require("lfs")

local source = {} -- buffer, will be concat'ed
local done = {}

table.insert(source, [[
<style>
	h1 { page-break-before: always; }
</style>
]])

local function add_page(name)
	if done[name] then return end
	done[name] = true
	
	local f = io.open(name, "r")
	local c = f:read("*a")
	f:close()
	table.insert(source, c)
end

add_page("docs/install-debian.md")
add_page("docs/internal-workings.md")
add_page("docs/global.md")

local files = {}
for file in lfs.dir("docs/") do
	if file ~= ".." and file ~= "." then
		file = "docs/" .. file
		table.insert(files, file)
	end
end
table.sort(files)

for k,v in pairs(files) do
	add_page(v)
end

local html = table.concat(source, "\n")
local contents = {"# Contents"}

local func = function(hashes, spaces, title)
	table.insert(contents, string.rep("\t", hashes:len() - 1) .. " - " .. title)
	
	return "\n" .. hashes .. spaces .. title .. "\n"
end

html = html:gsub("^(#+)(%s*)(.-)\n", func)
html = html:gsub("\n(#+)(%s*)(.-)\n", func)

print(table.concat(contents, "\n"))
print(html)
