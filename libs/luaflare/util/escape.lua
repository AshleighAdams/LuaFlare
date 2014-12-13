local url = require("socket.url")
local xssfilter = require("xssfilter")

--# luarocks install xssfilter
-- And until luarocks supports lua 5.2:
--# cp /usr/local/share/lua/5.1/xssfilter.lua /usr/local/share/lua/5.2/xssfilter.lua

local xss_filter = xssfilter.new({})

local escape = {}

function escape.pattern(input) expects "string" -- defo do not use string.Replace, else revusion err	
	return (string.gsub(input, "[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1"))
end

local http_safe = {}
local http_replacements = {}

for i = 32, 126 do
	http_safe[string.char(i)] = true
end
http_safe['"'] = nil
http_safe["'"] = nil
http_safe["<"] = nil
http_safe[">"] = nil
http_safe["&"] = nil
http_safe["\t"] = true
http_safe["\n"] = true
http_safe["\r"] = true

http_replacements["&"] = "&amp;"
http_replacements['"'] = "&quot;"
http_replacements["'"] = "&apos;"
http_replacements["<"] = "&lt;"
http_replacements[">"] = "&gt;"

local function http_safechar(char)
	if http_safe[char] then
		return char
	elseif http_replacements[char] then
		return http_replacements[char]
	else
		return string.format("&#%d;", string.byte(char))
	end
end

function escape.html(input, strict) expects "string"
	if strict == nil then strict = true end
	input = input:gsub(".", http_safechar)
	
	if strict then
		input = input:gsub("\t", "&nbsp;&nbsp;&nbsp;&nbsp;")
		input = input:gsub("\n", "<br />\n")
	end
	return input
end
escape.attribute = escape.html

function escape.url(input) expects "string"
	return url.escape(input)
end

function escape.striptags(input, tbl) expects "string"
	local html, message = xss_filter:filter(input)
	
	if html then
	   return html
	elseif message then
		error(message)
	end
	error("what?")
end

function escape.sql(input) expects "string"	
	input = input:gsub("'", "''")
	input = input:gsub("\"", "\"\"")
	
	return input
end

function escape.mysql(input) expects "string"	
	--[[
		 NUL (0x00) --> \0  [This is a zero, not the letter O]
		 BS  (0x08) --> \b
		 TAB (0x09) --> \t
		 LF  (0x0a) --> \n
		 CR  (0x0d) --> \r
		 SUB (0x1a) --> \Z
		 "   (0x22) --> \"
		 %   (0x25) --> \%
		 '   (0x27) --> \'
		 \   (0x5c) --> \\
		 _   (0x5f) --> \_ 
		 all other non-alphanumeric characters with ASCII values less than 256  --> \c
		 where 'c' is the original non-alphanumeric character.
	]]
		
	input = input:gsub("\\", "\\\\")
	input = input:gsub("\0", "\\0")
	input = input:gsub("\n", "\\n")
	input = input:gsub("\r", "\\r")
	input = input:gsub("\'", "\\\'")
	input = input:gsub("\"", "\\\"")
	input = input:gsub("\x1a", "\\Z")
	
	return input
end

function escape.argument(input, quoteify) expects "string"
	if quoteify == nil or quoteify then
		input = input:gsub("`", "\\`")
		input = input:gsub("$", "\\$")
		input = input:gsub("\"", "\\\"")
		
		return '"' .. input .. '"'
	else
		-- prefix with \:  " ' # & ; ` | ! * ? ~ < > ^ ( ) [ ] { } $ \ \x0A \xFF
		return input:gsub("[ %\"%\'%#%&%;%`%|%!%*%?%~%<%>%^%(%)%[%]%{%}%£%\\%\x0a%\xff]", "\\%1")
	end
end


return escape
