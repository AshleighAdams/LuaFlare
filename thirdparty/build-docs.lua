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

add_page("docs/command-line-arguments.md")
add_page("docs/install-debian.md")
add_page("docs/internal-workings.md")
add_page("docs/lua-extensions.md")
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

local p = io.popen("git describe --tags --always")
local version = p:read("*a"):match("([%d%.-]+)"):gsub("%-", ".")
p:close()

if version:sub(-1) == "." then
	version = version:sub(1, -2)
end

if arg[1] == "tex" then
	print("generating tex...")
	
	os.execute("pandoc -s -t latex tmp/docs.md -o tmp/docs.tex")

	local texf = io.open("tmp/docs.tex", "r")
	local tex = texf:read("*a")

	texf:close()
	texf = io.open("tmp/docs.tex", "w")

	tex = tex:gsub([[\begin{document}]], [[

	\usepackage{titlesec}
	\setcounter{secnumdepth}{4}

	\titleformat{\paragraph}
	{\normalfont\normalsize\bfseries}{\theparagraph}{1em}{}
	\titlespacing*{\paragraph}
	{0pt}{3.25ex plus 1ex minus .2ex}{1.5ex plus .2ex}


	\usepackage{geometry}
	\geometry{a4paper, margin=1in}

	\usepackage{listings}
	\lstset{
		breaklines=true,
		columns=fullflexible,
		basicstyle=\ttfamily,
		literate={--}{{-\,-}}1,
		literate={-}{{-}}1,
	}

	\usepackage{titling}
	\newcommand{\subtitle}[1]{%%
	  \posttitle{%%
		\par\end{center}
		\begin{center}\large#1\end{center}
		\vskip0.5em}%%
	}


	\title{LuaFlare Documentation}
	\subtitle{]]..version..[[}
	\usepackage{graphicx}

	\begin{document}

	\maketitle
	\begin{center}
		\includegraphics[width=\textwidth]{../logo.png}
	\end{center}

	\newpage
	\tableofcontents

	]])

	tex = tex:gsub("\\begin{verbatim}", "\\begin{lstlisting}")
	tex = tex:gsub("\\end{verbatim}", "\\end{lstlisting}")

	tex = tex:gsub("\\section", "\\newpage\n\\section")

	tex = tex:gsub("linkcolor=magenta,", "linkcolor=black,")

	texf:write(tex)
elseif arg[1] == "epub" then
	print("generating epub...")
	os.execute[[ebook-convert tmp/docs.md tmp/docs.epub \
		--title="LuaFlare Documentation" \
		--authors="Kate Adams" \
		--cover cover.png --preserve-cover-aspect-ratio \
		--chapter-mark=none \
		--use-auto-toc \
		--chapter="//*[((name()='h1' or name()='h2'or name()='h3')]" \
		--page-breaks-before="//*[name()='h1']" \
		--change-justification=justify \
		--epub-inline-toc \
		--level1-toc="//*[name()='h1']" \
		--level2-toc="//*[name()='h2']" \
		--level3-toc="//*[name()='h3']" \
		-v \
	]]
	os.execute[[unzip tmp/docs.epub -d tmp/docs]]
	os.execute[[sed -i "s/\"-/\"/g" tmp/docs/*.*]]
	os.execute[[sed -i "s/#-/#/g" tmp/docs/*.*]]
	os.execute[[cp cover.png tmp/docs/cover.png]]
	os.execute[[cd tmp/docs/ && zip -X ../docs-final.epub mimetype && zip -grX ../docs-final.epub META-INF/ *.*]]
	os.execute[[epubcheck tmp/docs-final.epub]]
else
	print("unknown format")
	os.exit(1)
end

