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
add_page("docs/bootstrap.md")
add_page("docs/global.md")

local files = {}
for file in lfs.dir("docs/") do
	if file ~= ".." and file ~= "." and file:sub(-3, -1) == ".md" then
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
os.execute("cp -r docs/images tmp/")

local f = io.open("tmp/docs.md", "w")
f:write(html)
f:close()

local p = io.popen("git describe --tags --always")
local version = p:read("*a"):match("([%d%.-]+)"):gsub("%-", ".")
p:close()

if version:sub(-1) == "." then
	version = version:sub(1, -2)
end

if arg[1] == "pdf" or arg[1] == "tex" then
	print("generating pdf via LaTeX...")
	
	os.execute("pandoc -s -t latex tmp/docs.md -o tmp/luaflare-documentation.tex")

	local texf = io.open("tmp/luaflare-documentation.tex", "r")
	local tex = texf:read("*a")

	texf:close()
	texf = io.open("tmp/luaflare-documentation.tex", "w")

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
	\sloppy %% so that some \texttt's wrap
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
	--tex = tex:gsub("images/", "../images/")

	texf:write(tex)
	
	if arg[1] == "pdf" then
		-- os.execute breaks this, idk why
		local proc = io.popen("cd tmp && TERM=none latexmk --pdf luaflare-documentation.tex")
	
		while true do
			local line = proc:read("*l")
			if not line then break end
			print(line)
		end
	end
	
	proc:close()
elseif arg[1] == "epub" then
	print("generating epub...")
	os.execute[[ebook-convert tmp/docs.md tmp/luaflare-documentation.epub \
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
	os.execute[[unzip tmp/luaflare-documentation.epub -d tmp/docs]]
	os.execute[[sed -i "s/\"-/\"/g" tmp/docs/*.*]]
	os.execute[[sed -i "s/#-/#/g" tmp/docs/*.*]]
	
	-- modify the stylesheet
	print("fixing stylesheet...")
	local ss = assert(io.open("tmp/docs/stylesheet.css", "r"))
	local ss_c = ss:read("*a") ss:close()
	ss = assert(io.open("tmp/docs/stylesheet.css", "w"))
	
	ss:write(ss_c .. [[
h1, h2, h3, h4, h5, h6 {
	text-align: left;
	text-indent: -1em;
	padding-left: 1em;
}
code {
	text-align: left;
}
p {
	text-align: justify;
}
]])
	ss:flush()
	ss:close()
	
	-- images become corrupted with unzip for some reason, so replace them with the originals...
	os.execute[[cp cover.png tmp/docs/cover.png]]
	os.execute[[cp docs/images/* tmp/docs/]]
	
	os.execute[[cd tmp/docs/ && zip -X ../luaflare-documentation-final.epub mimetype && zip -grX ../luaflare-documentation-final.epub META-INF/ *.*]]
	os.execute[[epubcheck tmp/luaflare-documentation-final.epub]]
else
	print("unknown format")
	os.exit(1)
end

