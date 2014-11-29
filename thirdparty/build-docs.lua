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

html = html:gsub("\\", "\\\\") -- escape these for the latex doc
--print(table.concat(contents, "\n"))
os.execute("rm -rf tmp/")
os.execute("mkdir tmp")

local f = io.open("tmp/docs.md", "w")
f:write(html)
f:close()

os.execute("pandoc -s -t latex tmp/docs.md -o tmp/docs.tex")
--os.execute([[sed -i "s|\n''|\\n''|g" tmp/docs.tex]]) -- fix \n being wrote as 

local texf = io.open("tmp/docs.tex", "r")
local tex = texf:read("*a")

texf:close()
texf = io.open("tmp/docs.tex", "w")

tex = tex:gsub([[\begin{document}]], [[

\usepackage{geometry}
\geometry{legalpaper, margin=1in}

\usepackage{listings}
\lstset{breaklines=true}

\title{LuaFlare Documentation}
\author{Kate Adams <self@kateadams.eu>}

\begin{document}
\maketitle
\newpage
\tableofcontents

]])

tex = tex:gsub("\\begin{verbatim}", "\\begin{lstlisting}")
tex = tex:gsub("\\end{verbatim}", "\\end{lstlisting}")

tex = tex:gsub("\\section", "\\newpage\n\\section")

tex = tex:gsub("linkcolor=magenta,", "linkcolor=black,")

texf:write(tex)





