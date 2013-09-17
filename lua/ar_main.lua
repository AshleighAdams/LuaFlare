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
				hook.Call("Error", {type = 501, message = "code took too long to execute"}, req, res)
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
reqs.AddPattern("*", "/runlua", run_lua_page)

hook.Add("LuaGetLine", "locate runstring", function(err)
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
	
	res:append("<table>")
	res:append(string.format("<td>%s</td><td>%s</td>", "<b>Host</b>&nbsp;&nbsp;&nbsp;&nbsp;", "<b>URL</b>"))
	for _, hk in pairs(reqs.PatternsRegistered) do
		res:append("<tr>")
		res:append(string.format("<td>%s</td><td>%s</td>", escape.html(hk.host),
			escape.html(hk.url)))
		res:append("</tr>")
	end
	res:append("/<table>")
end
reqs.AddPattern("*", "/info", get_info)