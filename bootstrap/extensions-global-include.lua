local G = {}

local stack = require("luaflare.util.stack")
local translate_luacode = require("luaflare.util.translate_luacode")
local parser = require("luaflare.util.luaparser")
local hook = require("luaflare.hook")

local col_red = "\x1b[31;1m"
local col_bold = "\x1b[39;1m"
local col_reset = "\x1b[0m"
function G.warn(str, ...) expects("string") -- print a warning to stderr
	if table.pack(...).n ~= 0 then
		str = str:format(...)
	end
	
	local outstr = string.format("%s%s%s", col_bold, str, col_reset)
	local ret = {}
	
	hook.call("Warning", str, ret)
	if not ret.silence then
		io.stderr:write(outstr.."\n")
	end
end

function G.fatal(str, ...) expects("string") -- print a warning to stderr
	if table.pack(...).n ~= 0 then
		str = str:format(...)
	end
	
	local outstr = string.format("%s%s%s", col_red, str, col_reset)
	local ret = {fatal = true}
	
	hook.call("Warning", str, ret)
	if not ret.silence then
		io.stderr:write(outstr.."\n")
	end
end

-- include helpers
G.loadfile = function(file, ...)
	local f = assert(io.open(file, "r"))
	local code = f:read("*a")
	f:close()
	
	code = translate_luacode(code)
	return loadstring(code, file)
end

G.dofile = function(file, ...)
	local f = assert(io.open(file, "r"))
	local code = f:read("*a")
	f:close()
	
	code = translate_luacode(code)
	local f, err = loadstring(code, file)
	
	if not f then
		fatal("failed to loadstring: %s", err)
		return error(err, -1)
	end
	
	return f(...)
end


local stacks = stack()
local current = stack()
function G.include(file, ...) expects "string"
	package.included = package.included or {}

	local err = nil -- if this != nil at the end, call error with this string
	local path = file:path()
	file = file:sub(path:len() + 1)

	current:push((current:value() or "") .. path)
		for k,v in ipairs(stacks:all()) do
			v(current:value() .. file)
		end
		
		local deps = {}
		local function on_dep(dep)
			table.insert(deps, dep)
		end
		
		stacks:push(on_dep)
			local ret = {pcall(dofile, current:value() .. file, ...)}
			local success = table.remove(ret, 1) -- pcall returns `succeded, f()`, remove the top value
			
			if success == false then -- failed to compile...
				err = ret[1] -- the top of the ret table == the error string
			else -- Add it to the registry
				local file = current:value() .. file
				package.included[file] = package.included[file] or {}

				for k, v in pairs(ret) do
					if type(v) == "table" then
						if package.included[file][k] == nil then
							-- on first itteration, just set it
							package.included[file][k] = v
						else
							-- otherwise, update the values
							local tbl = package.included[file][k]

							-- clear the table
							for k, v in pairs(tbl) do
								tbl[k] = nil
							end
							-- and update with new stuff
							for k, vv in pairs(v) do
								tbl[k] = vv
							end

							ret[k] = tbl
						end
					else
						package.included[file][k] = v
					end
				end
			end
		stacks:pop()
	current:pop()
	
	if err ~= nil then error(string.format("while including: %s: %s", file, err), -1) end
	return unpack(ret), deps
end

local function package_loaded_auto(tokens, module)
	-- local x = {...}
	-- ...
	-- return x
	
	-- should be translated to:
	
	-- local x = {...}; package.loaded[...] = x
	-- ...
	-- return x
	
	local function nope(why)
		bootstrap.log("automatic circular require: %s: mod table not found (%s)", module, why)
	end
	
	local en, last1, last2 = #tokens
	
	last2, en = parser.previous_token(tokens, en)
	last1, en = parser.previous_token(tokens, en)
	
	local sn, first1, first2, first3, first4 = 0
	first1, sn = parser.next_token(tokens, sn)
	first2, sn = parser.next_token(tokens, sn)
	first3, sn = parser.next_token(tokens, sn)
	first4, sn = parser.next_token(tokens, sn)
	
	-- now check if the tokens we got are all present and valid
	if
		not first1 or not first2 or not first3 or not first4 or
		not last1 or not last2
	then
		return nope("empty-ish file")
	end
	
	if     first1.chunk ~= "local"
		or first2.type ~= "identifier"
		or first3.chunk ~= "="
		or first4.chunk ~= "{"
	then
		--print(first1.chunk,first2.chunk,first3.chunk,first4.chunk)
		return nope("first tokens != local $modname = {$...}")
	end
	
	if     last1.chunk ~= "return"
		or last2.type ~= "identifier"
		or last2.value ~= first2.value
	then
		return nope("last tokens != return $modname")
	end
	
	-- find the end of the { {$...}
	local brackets_in  = parser.brackets_create
	local brackets_out = parser.brackets_destroy
	local depth = 1
	local nt
	while true do
		nt, sn = parser.next_token(tokens, sn)
		if not nt then
			return nope("could not locate end of first table")
		end
		
		if nt.type == "token" then
			if brackets_in[nt.value] then
				depth = depth + 1
			elseif brackets_out[nt.value] then
				depth = depth - 1
				if depth < 0 then
					return parser.problem("too many brackets closed in expression near function " .. table.concat(table_to, ".") .. name)
				end
			end
			
			if nt.value == "}" then
				break
			end
		end
	end
	
	bootstrap.log("automatic circular require: setting early %s as %s", module, first2.value)
	
	-- append our pre-loader onto the chunk!
	nt.chunk = nt.chunk .."; package.loaded[...] = " .. first2.value
end

local require_dofile_lexer = function(mod, file)
	local f = assert(io.open(file, "r"))
	local code = f:read("*a")
	f:close()
	
	code = translate_luacode(code, {
		ModifyTokens = function(tk)
			package_loaded_auto(tk, mod)
		end
		})
	local f, err = loadstring(code, file)
	
	if not f then
		fatal("failed to loadstring: %s", err)
		return error(err, -1)
	end
	
	return f(mod)
end

local require_dofile_debug = function(module, file)
	local f, err = loadfile(file)
	
	if not f then
		fatal("failed to loadfile: %s", err)
		return error(err, -1)
	end
	
	-- set a hook and try to detect the first empty table
	local a,b,c = debug.gethook()
	local module, file = module, file -- save it as a local for use in the hook
	local remove_hook = false
	local self_path = debug.getinfo(2).short_src
	
	local function tester()
		if remove_hook then -- needs to be at the top, else it segfaults
			debug.sethook(a, b, c)
			return
		end
	
		local info = debug.getinfo(2)
	
		if info.short_src == self_path then
			-- this is our hook, let's just ignore it
			return
		elseif info.func ~= f then
			bootstrap.log("warning: while require()ing %s (%s): could not automatically detect module table",
				module, file)
			remove_hook = true
			return
		end
	
		local key, value
		local i, found = 0, false
		while true do
			i = i + 1
			key, value = debug.getlocal(2, i)
			if not key then break end
			local istmp = key == "(*temporary)"
			if type(value) == "table" and not istmp and table.count(value) == 0 then
				found = true
				break
			--elseif not istmp then
			--	print(key, value)
			end
		end
	
		if found then
			bootstrap.log("automatic circular require: setting early %s as %s", module, key)
			package.loaded[module] = key
			remove_hook = true
		end
	end

	debug.sethook(tester, "l", 1)
	
	local r = f(module)
	
	-- reset it if it still didn't...
	debug.sethook(a,b,c)
	
	return r
end

local require_dofile = require_dofile_lexer

local real_require = require
function G.require(mod)
	if package.loaded[mod] then
		return package.loaded[mod]
	elseif package.preload[mod] then
		return real_require(mod)
	end
	
	local file = package.searchpath(mod, package.path)
	
	if file then
		local m = require_dofile(mod, file, mod)
		package.loaded[mod] = m ~= nil and m or true -- if a require returns nil, this is set to true instead
		return m
	end
	
	return real_require(mod)
end

return G
