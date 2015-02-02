local session = require("luaflare.session")
local hosts = require("luaflare.hosts")
local hook = require("luaflare.hook")
local tags = require("luaflare.tags")
local escape = require("luaflare.util.escape")

local function translate(req, res, filename)
	filename = filename:trim()
	
	if filename:match("%.%.") ~= nil then
		return res:halt(403, "Path contains \"..\"!") -- forbidden
	elseif filename:starts_with("/") then
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


local parser = require("luaflare.util.luaparser")
local escape = require("luaflare.util.escape")
local util = require("luaflare.util")

local function tokenize(req, res, filename)
	filename = filename:trim()
	
	if filename:match("%.%.") ~= nil then
		return res:halt(403, "Path contains \"..\"!") -- forbidden
	elseif filename:starts_with("/") then
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
	if params.parse then
		local parsed = assert(parser.parse(tokens))
		res:append(table.to_string(parsed))
	elseif params.line then
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


do
	local websocket = require("luaflare.websocket")
	
	local ws = websocket.register("/websocket-test", "echo")
	function ws:on_connect(client)
		print("echo: connect: " .. client.peer)
		self:send(client.peer .. " connected")
	end
	function ws:on_message(client, message)
		print("echo: message: " .. client.peer .. ": " .. message)
		self:send(client.peer .. ": " .. message)
	end
	function ws:on_disconnect(client)
		print("echo: disconnect: " .. client.peer)
		self:send(client.peer .. " disconnected")
	end
	
	local function websocket_test(req, res)
		res:append[[
		<script>
		var websocket
		function connect()
		{
			websocket = new WebSocket("ws://" + location.host + "/websocket-test", "echo");
			websocket.onopen = function(e) {};
			websocket.onclose = function(e) {setTimeout(1000, "connect()");};
			websocket.onmessage = function(e)
			{
				var msgs = document.getElementById("msgs");
				var p = document.createElement("p");
				var t = document.createTextNode(e.data);
				p.appendChild(t);
				msgs.appendChild(p);//, msgs.firstChild);
			};
			websocket.onerror = function(e) {};
		}
		connect();
		
		function send(e)
		{
			var el = document.getElementById("msg");
			websocket.send(el.value);
			el.value = "";
		}
		</script>
		<form action="#" onsubmit="send()">
			<input type=text id=msg />
			<input type=submit />
		</form>
		<div id=msgs>
			<p><b>Messages:</b></p>
		</div>
		]]
	end
	hosts.any:add("/websocket-test", websocket_test)
end

local function test_post(req, res)
	res:append("OKAY")
end
hosts.any:add("/test-post", test_post, "POST")
