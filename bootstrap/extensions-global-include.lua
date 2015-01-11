local G = {}

local stack = require("luaflare.util.stack")
local translate_luacode = require("luaflare.util.translate_luacode")
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

local real_require = require
function G.require(mod)
	if package.loaded[mod] then
		return package.loaded[mod]
	elseif package.preload[mod] then
		return real_require(mod)
	end
	
	local file = package.searchpath(mod, package.path)
	
	if file then
		local m = dofile(file, mod)
		package.loaded[mod] = m ~= nil and m or true -- if a require returns nil, this is set to true instead
		return m
	end
	
	return real_require(mod)
end

return G
