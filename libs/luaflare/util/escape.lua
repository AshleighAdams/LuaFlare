local escape = {}

local url = require("socket.url")
local xssfilter = require("xssfilter")
local script = require("luaflare.util.script")
local hook = require("luaflare.hook")

--# luarocks install xssfilter
-- And until luarocks supports lua 5.2:
--# cp /usr/local/share/lua/5.1/xssfilter.lua /usr/local/share/lua/5.2/xssfilter.lua

local xss_filter = xssfilter.new({})

function escape.pattern(string input)
	return (string.gsub(input, "[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%1"))
end

local http_replacements = {}

for i = 32, 126 do
	http_replacements[string.char(i)] = string.char(i)
end
http_replacements["&"] = "&amp;"
http_replacements['"'] = "&quot;"
http_replacements["'"] = "&apos;"
http_replacements["<"] = "&lt;"
http_replacements[">"] = "&gt;"
http_replacements["\n"] = "\n"
http_replacements["\r"] = "\r"
http_replacements["\t"] = "\t"

local warn_bucket_size = 1024
local function set_bucket_size()
	warn_bucket_size = tonumber(script.options["escape-html-warn-buckets"]) or 1024
end
hook.add("Loaded", "--escape-html-warn-buckets", set_bucket_size)

setmetatable(http_replacements, {
	__index = function(self, k)
		local c = string.format("&#%d;", string.byte(k))
		http_replacements[k] = c
		
		local bc = table.count(http_replacements)
		
		if bc >= warn_bucket_size then
			warn("escape.html() bucket size: %d", bc)
		end
		return c
	end
})

function escape.html(string input, boolean strict = true)
	input = input:gsub(".", http_replacements)
	
	if strict then
		input = input:gsub("\t", "&nbsp;&nbsp;&nbsp;&nbsp;")
		input = input:gsub("\n", "<br />\n")
	end
	return input
end
escape.attribute = escape.html

function escape.url(string input)
	return url.escape(input)
end

function escape.striptags(string input, tbl)
	local html, message = xss_filter:filter(input)
	
	if html then
	   return html
	elseif message then
		error(message)
	end
	error("what?")
end

function escape.sql(string input)
	input = input:gsub("'", "''")
	input = input:gsub("\"", "\"\"")
	
	return input
end

function escape.mysql(string input)
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

function escape.argument(string input, boolean quoteify = true)
	if quoteify then
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
