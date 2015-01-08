local escape = require("luaflare.util.escape")

local slug = {}

slug.seperator = "-"

slug.readable_chars = {
	["-"] = true,
	a=true,b=true,c=true,d=true,e=true,f=true,d=true,e=true,f=true,g=true,h=true,
	i=true,j=true,k=true,l=true,m=true,n=true,o=true,p=true,q=true,r=true,s=true,
	t=true,u=true,v=true,w=true,x=true,y=true,z=true,
	["0"]=true,["1"]=true,["2"]=true,["3"]=true,["4"]=true,["5"]=true,["6"]=true,
	["7"]=true,["8"]=true,["9"]=true,
}

-- use a space for separators
slug.aliases = {
	[" "] = " ",
	["_"] = " ",
	["."] = " ",
	[","] = " ",
	[":"] = " ",
	[";"] = " ",
	["&"] = " and ",
	["@"] = " at ",
	["%"] = " percent ",
	["-"] = " minus ",
	["+"] = " plus ",
	["/"] = " div ",
	["*"] = " mul ",
	["$"] = " usd",
	["£"] = " gbp",
}

for i = string.byte("A"), string.byte("Z") do
	local c = string.char(i)
	slug.aliases[c] = c:lower()
end

--[[ /etc/slugs proposal: <char>\t<replacement>\n
&	 and 
@	 at 
.	 
$	 usd
--]]

-- try in this order: aliases, readable, empty
function slug.slug_char(character x)

	if slug.aliases[x] then -- try an alias
		return slug.aliases[x]
	elseif slug.readable_chars[x] ~= nil then
		return x
	else
		-- let's try to use `unaccent`
		local p = io.popen("unaccent UTF-8 " .. escape.argument(x))
		local r = p:read(1)
		p:close()
		
		-- translate it (i.e., may be E with an accent, so E` -> E -> e).
		r = slug.aliases[r] or slug.readable_chars[r] or ""
		slug.aliases[x] = r
		
		print(("slug_char: %q -> %q"):format(x, r))
		
		return r -- no alias, and not valid
	end
	
end

function slug.generate(string input)
	input = input:gsub(".", slug.slug_char)
	input = input:gsub("%s", "-")
	input = input:gsub("[%-][%-]*", "-") -- turn many dashes into just one
	input = input:match("^[%-]*(.-)[%-]*$") -- trim any dashes
	
	return input
end

return slug
