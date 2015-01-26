local profiler = {}

local util = require("luaflare.util")
local escape = require("luaflare.util.escape")

local function shorten(v)
	local shortstr = tostring(v)
		:gsub("[\n]", "\\n")
		:gsub("[\r]", "\\r")
		:gsub("[\t]", "\\t")
	if shortstr:len() > 32 then
		shortstr = shortstr:sub(1, 32 - 3) .. "..."
	end
	if type(v) == "string" then
		return ("\"%s\""):format(shortstr)
	else
		return shortstr
	end
end

function profiler.start(string filename = "profile.log")
	local time = util.time
	profiler.output = io.open(filename, "w")
	
	local args_len = {}
	
	debug.sethook(function(why)
		why = why == "call" and "+" or "-"
	
		local info = debug.getinfo(2, "nSu")
		local args_str = ""
	
		if why == "+" then
			local args = {}
			if info.source == "=[C]" then
				local i = 0
				while true do
					i = i + 1
					local k,v = debug.getlocal(2, i)
					if k ~= "(*temporary)" then break end
					
					table.insert(args, shorten(v))
				end
				args[#args] = nil -- the last one is some idk var
			else
				for i = 1, info.nparams do
					local k,v = debug.getlocal(2, i)
					table.insert(args, shorten(v))
				end
			end
			
			args_len[#args_len] = #args
			args_str = escape.html(table.concat(args, ", "))
		else--if info.source ~= "=[C]" then
			-- returns, only do for Lua funcs (C funcs don't work the same)
			local rets = {}
			local i = args_len[#args_len] or 0
			args_len[#args_len] = nil
			
			--[[
			if info.source ~= "=[C]" then
				i = c_args_len[#c_args_len]
				c_args_len[#c_args_len] = nil
			else
				i = info.nparams
			end]]
			
			--i = math.max(0, i - 1)
			
			while true do
				i = i + 1
				local k,v = debug.getlocal(2, i)
				if not k then break end
				
				--print(info.name, info.nparams)
				
				if k == "(*temporary)" then
					table.insert(rets, shorten(v))
				end
			end
			rets[#rets] = nil -- last one is idk what again
			args_str = escape.html(table.concat(rets, ", "))
		end
	
		profiler.output:write(string.format("%f\t%s\t%s\t%s:%d\t%s\n", time(), why, info.name or "", info.short_src, info.linedefined, args_str))
	end, "cr")
end

function profiler.stop()
	debug.sethook()
	profiler.output:flush()
	profiler.output:close()
	profiler.output = nil
end

return profiler
