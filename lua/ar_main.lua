local session = require("luaserver.session")
local hosts = require("luaserver.hosts")
local hook = require("luaserver.hook")
local tags = require("luaserver.tags")
local escape = require("luaserver.util.escape")

local template = tags.html
{
	tags.head
	{
		tags.title { tags.SECTION },
		tags.link {rel = "stylesheet", type = "text/css", href = "/error_style.css"}
	},
	tags.body
	{
		tags.div {class = "bg_wrapper"}
		{
			tags.div {class = "wrapper"}
			{
				tags.p {style = "font-size: 22; margin-top: 0px; border-bottom: 1px solid #dddddd"}
				{
					tags.SECTION
				},
				tags.SECTION
			}
		},
		tags.div {class = "footer"}
		{
			string.format("pid: %i", script.pid())
		}
	}
}

local last_runlua = ""
local function run_lua_page(req, res)
	local content = tags.div
	{
		tags.p { "Run Lua code:" },
		tags.form {method = "post", action = "/runlua"}
		{
			tags.SECTION,
			tags.input{type = "submit"}
		},
		tags.div {class = "box nowrap"}
		{
			tags.SECTION
		}
	}
	
	local title = "Run Lua"
	local lua = req:post_data().lua or [[function fact (n)
    if n == 0 then
        return 1
    else
        return n * fact(n-1)
    end
end


return fact(4)]]
	
	template.to_response(res, 0) -- <title>
	res:append(title)
	template.to_response(res, 1) -- header
	res:append(title)
	template.to_response(res, 2) -- content
	
		content.to_response(res, 0)
		res:append("<textarea name='lua' rows=20 cols=68>\n")
		res:append(escape.html(lua, false))
		res:append("</textarea>\n")
		
		content.to_response(res, 1)
			-- output
			
			local function print(...)
				local prefix = ""
				
				local args = {...}
				
				for i=1, #args do
					local v = args[i]
					res:append(escape.html(prefix .. tostring(v)))
					prefix = ", \t"
				end
				
				if prefix ~= "" then
					res:append(escape.html("\n"))
				end
			end
			
			local function timeout()
				hook.call("Error", {type = 501, message = "code took too long to execute"}, req, res)
				error("function timed out", 2)
			end
			
			
			------------------------------ ENVIROMENT
			local meta_tables = {}

			local function safe_setmetatable(tbl, meta)
				if getmetatable(tbl) and meta_tables[tbl] == nil then return error("sandbox error: unsafe setmetatable!", 2) end

				meta_tables[tbl] = meta
				setmetatable(tbl, meta)
			end

			local function safe_getmetatable(tbl)
				return meta_tables[tbl]
			end
			
			local function safe_stringrep(str, count)
				if (#str + count) > 1000 then error("count is too big", 2) end
				return string.rep(str, count)
			end
			
			local env = {
				print = print,
				ipairs = ipairs, tonumber = tonumber, next = next, pairs = pairs, 
				pcall = pcall, tonumber = tonumber, tostring = tostring, type = type,
				unpack = unpack, setmetatable = safe_setmetatable, getmetatable = safe_getmetatable, 
				coroutine = {
					create = coroutine.create, resume = coroutine.resume, 
					running = coroutine.running, status = coroutine.status, 
					wrap = coroutine.wrap, yield = coroutine.yield
				},
				string = { 
					byte = string.byte, char = string.char, find = string.find, 
					format = string.format, gmatch = string.gmatch, gsub = string.gsub, 
					len = string.len, lower = string.lower, match = string.match, 
					rep = safe_stringrep, reverse = string.reverse, sub = string.sub, 
					upper = string.upper
				},
				table = {
					insert = table.insert, maxn = table.maxn, remove = table.remove, 
					sort = table.sort, concat = table.concat
				},
				math = { --table.Copy(math)
					abs = math.abs, acos = math.acos, asin = math.asin, 
					atan = math.atan, atan2 = math.atan2, ceil = math.ceil, cos = math.cos, 
					cosh = math.cosh, deg = math.deg, exp = math.exp, floor = math.floor, 
					fmod = math.fmod, frexp = math.frexp, huge = math.huge, 
					ldexp = math.ldexp, log = math.log, log10 = math.log10, max = math.max, 
					min = math.min, modf = math.modf, pi = math.pi, pow = math.pow, 
					rad = math.rad, random = math.random, sin = math.sin, sinh = math.sinh, 
					sqrt = math.sqrt, tan = math.tan, tanh = math.tanh
				},
				--os = { clock = os.clock, difftime = os.difftime, time = os.time },
				--bit = {
				--	tobit = bit.tobit, tohex = bit.tohex, bnot = bit.bnot,
				--	band = bit.band, bor = bit.bor, bxor = bit.bxor,
				--	lshift = bit.lshift, rshift = bit.rshift, 
				--	arshift = bit.arshift, rol = bit.rol, ror = bit.ror, 
				--	bswap = bit.bswap
				--},
			}
			
			env._G = env
			last_runlua = lua
			
			
			local func, err
			do
				func, err = load(lua, "runlua", nil, env)
			end
			
			if not func then error(err, -1) end
						
			-- not anymore
			-- setfenv(func, env)
			
			--------------------------------------------------- END ENV
			
			local oldhook = debug.gethook()
			debug.sethook(timeout, "", 1000)
			local rets = {pcall(func)}
			
			if not rets[1] then
				debug.sethook(oldhook)
				error(rets[2], -1)
				return
			end
			table.remove(rets, 1)
			debug.sethook(oldhook)
			
			
			
			local prefix = "returned "
			for k,v in pairs(rets) do
				res:append(escape.html(prefix .. to_lua_value(v)))
				prefix = ", "
			end
		content.to_response(res, 2)
		
	template.to_response(res, 3)
end
hosts.developer:add("/runlua", run_lua_page)

hook.add("LuaGetLine", "locate runstring", function(err)
	local line_num = err:match('%[string "runlua"]:(%d+): ')
	
	if line_num then
		line_num = tonumber(line_num)
		local line = ""
		
		for i=1, last_runlua:len() do
			local char = last_runlua:sub(i, i)
			
			if char == '\n' then
				line_num = line_num - 1
				if line_num == 0 then break end
				line = ""
			else
				line = line .. char
			end
		end
		
		return line
	end
end)


local function get_info(req, res)
	res:append("Headers: " .. escape.html(table.ToString(req:headers())))	
	res:append("script path: " .. script.local_path("") .. "\n")
	res:append("<table>")
	for hook,v in pairs(hook.hooks) do
		res:append("<tr>")
		res:append("<td>" .. escape.html(hook) .. "<td/>")
		res:append("<td><table>")
		for name, vv in pairs(v) do
			res:append("<tr><td>")
			res:append(escape.html(name))
			res:append("</td></tr>")
		end
		res:append("</table><td>")
		res:append("</tr>")
	end
	res:append("</table>")
	
	res:append("<h2>Hosts & Pages</h2>")
	
	for k,host in pairs(hosts.hosts) do
		res:append("<h3>" .. escape.html(k) .. " - Patterns</h3>")
		for kk,page in pairs(host.page_patterns) do
			res:append(kk .. "<br/>")
		end
		
		res:append("<h3>" .. escape.html(k) .. " - Direct</h3>")
		for kk,page in pairs(host.pages) do
			res:append(kk .. "<br/>")
		end
	end
	--[[
	res:append("<table>")
	res:append(string.format("<td>%s</td><td>%s</td>", "<b>Host</b>&nbsp;&nbsp;&nbsp;&nbsp;", "<b>URL</b>"))
	for _, hk in pairs(reqs.PatternsRegistered) do
		res:append("<tr>")
		res:append(string.format("<td>%s</td><td>%s</td>", escape.html(hk.host),
			escape.html(hk.url)))
		res:append("</tr>")
	end
	res:append("/<table>")
	]]

	local last = tonumber(req:get_cookie("hits")) or 0
	res:append(tostring(last) .. "<br/>\n")
	res:set_cookie("hits", tostring(last + 1))

	local sess = session.get(req, res)
	local data = sess:data()
	data.hits = (data.hits or 0) + 1
	sess:save()

	res:append("session = " .. escape.html(table.ToString(data)))
end
hosts.developer:add("/info", get_info)


local function translate(req, res, filename)
	filename = filename:Trim()
	
	if filename:match("%.%.") ~= nil then
		return res:halt(403, "Path contains \"..\"!") -- forbidden
	elseif filename:StartsWith("/") then
		return res:halt(403, "Path starts with \"/\"!") -- forbidden
	end
	
	local f = io.open(filename, "r")
	if not f then return res:halt(404, filename) end
	local code = util.translate_luacode(f:read("*a"))
	f:close()
	
	res:append(code)
	res:set_header("Content-Type", "text/plain")
end
hosts.developer:addpattern("/translate/(.+)", translate)


local parser = require("luaserver.util.luaparser")
local escape = require("luaserver.util.escape")
local util = require("luaserver.util")

local function tokenize(req, res, filename)
	filename = filename:Trim()
	
	if filename:match("%.%.") ~= nil then
		return res:halt(403, "Path contains \"..\"!") -- forbidden
	elseif filename:StartsWith("/") then
		return res:halt(403, "Path starts with \"/\"!") -- forbidden
	end
	
	local f = io.open(filename, "r")
	if not f then return res:halt(404, filename) end
	local code = f:read("*a")
	f:close()
	
	local tstart, ttokens, thooks, tscope
	tstart = util.time()
	local tokens = parser.tokenize(code)
	ttokens = util.time() - tstart
	
	tstart = util.time()
	hook.call("ModifyTokens", tokens)
	hook.call("OptimizeTokens", tokens)
	thooks = util.time() - tstart
	
	tstart = util.time()
	local scope = parser.read_scopes(tokens)
	tscope = util.time() - tstart
	
	local function printscope(scope, depth)
		depth = depth or ""
		local locals = {}
		for k,v in pairs(scope.locals) do
			if v.argument then
				table.insert(locals, "("..v.name..")")
			else
				table.insert(locals, v.name)
			end
		end
		res:append(depth.."scope {\n")
		res:append(depth.."\tlocals: " .. table.concat(locals, ", ") .. "\n")
		for k,v in pairs(scope.children) do
			printscope(v, depth.."\t")
		end
		res:append(depth.."}\n")
	end
	
	local params = req:params()
	if params.line then
		local tk
		local curline, line = 1, tonumber(params.line) or 1
		for k,t in pairs(tokens) do
			if t.type == "newline" then
				curline = curline + 1
			end
			if curline >= line then
				tk = t
				break
			end
		end
		
		assert(tk)
		
		local locals = {}
		local scope = tk.scope
		while scope do
			res:append("parent scope:\n")
			for k,l in pairs(scope.locals) do
				if l.range[1] < tk.range[1] then
					res:append(string.format("\t%s%s\n", l.name, l.argument and "*" or ""))
				end
			end
			scope = scope.parent
		end
	elseif params.scope then
		printscope(scope)
	else
		res:append([[
			<style>
				div, p, a, li, td { -webkit-text-size-adjust:none; }
				body {
					font-family: monospace;
					font-size: 11pt;
					background-color: #333;
					color: #fff;
				}
				table {
				}
				.whitespace {
					/*border: 1px solid #2a2a2a;*/
					border-bottom: 1px solid #3f3f3f;
					margin-left: 1px;
					margin-right: 1px;
				}
				.keyword {
					font-weight: bold;
				}
				.string {
					color: yellow;
				}
				.number {
					color: orange;
				}
				.comment {
					color: #aaa;
				}
				.identifier {
					/*color: #acf;*/
					/*text-decoration: underline;*/
				}
				.function {
					/*color: #acf;*/
					font-style: oblique;
				}
				.indexer {
					color: #afc;
				}
				td.lines {
					text-align: right;
					color: #aaa;
					vertical-align: top;
					padding-right: 1em;
				}
				td.code {
					white-space: nowrap;
					vertical-align: top;
				}
				.token {
					/*border: 1px solid #555;*/
					color: acf;
				}
				.newline {
					color: #3f3f3f;
				}
			</style>
			Key: <span class='keyword'>keyword</span> <span class='string'>string</span> <span class='number'>number</span> <span class='comment'>comment</span
			> <span class='identifier'>identifier</span> <span class='function'>function</span> <span class='indexer'>indexer</span> <span class='token'>token</span
			> <span class='whitespace'>whitespace</span> <br/>
		]])
		
		res:append("Tokens: " .. (ttokens*1000) .. "ms ")
		res:append("Hooks: " .. (thooks*1000) .. "ms ")
		res:append("Scope: " .. (tscope*1000) .. "ms ")
		
		local identifier_ids = {}
		local id = 1
		
		local lines = {}
		code:gsub("\r?\n", function()
			table.insert(lines, #lines + 1)
		end)
		lines = table.concat(lines, "<br/>\n")
		
		local function next_token(pos, count)
			local k,t = pos,nil
			count = count or 1
			while count > 0 do
				k = k + 1
				t = tokens[k]
				if not t then break
				elseif not (t.type == "whitespace" or t.type == "newline") then
					count = count - 1
				end
			end
			return t,k
		end
		
		res:append("<table>")
		res:append("<td class='lines'>")
		res:append(lines)
		res:append("</td><td class='code'>")
		for k,t in ipairs(tokens) do
			if t.type == "newline" then
				res:append("<span class='newline'>&#8629;</span><br\n/>")
			else
				local class = t.type
				
				if t.defines ~= nil then
					class = class .. " defines"
				end
				
				local nt = next_token(k)
				if t.type == "identifier" and nt and nt.type == "token" and nt.value == "(" then
					class = class .. " function"
				end
				if t.indexer then
					class = class .. " indexer"
				end
				res:append("<span class='" .. escape.attribute(class) .. "'>")
				res:append(escape.html(t.chunk))
				res:append("</span>")
			end
		end
		res:append("</td></table>")
		return
	end
	
	res:set_header("Content-Type", "text/plain")
end
hosts.developer:addpattern("/tokenize/(.+)", tokenize)


local function conflict1(req, res, ...)
	res:append("OK - 1: " .. table.concat({...}, ", "))
end
local function conflict2(req, res, ...)
	res:append("OK - 2: " .. table.concat({...}, ", "))
end
hosts.developer:addpattern("/conflict/(*)", conflict1)
hosts.developer:addpattern("/conflict/(%d+)", conflict2)
