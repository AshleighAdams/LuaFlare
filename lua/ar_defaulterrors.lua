
local httpstatus = require("luaflare.httpstatus")
local hook = require("luaflare.hook")
local tags = require("luaflare.tags")
local lfs = require("lfs")

local template = include("template-error.lua")

local function on_error(why, request, response)
	print(string.format("fail: %s: %s %s", why.type, request:path(), why.message or ""))
end
hook.add("Error", "log errors", on_error)

local function basic_error(why, req, res)
	res:clear_content()
	
	local errcode = why.type or 500
	local errstr = string.format("%i %s", errcode, httpstatus.tostring(errcode) or "Unknown")
	local msg = why.message or req:path()
	
	res:append(template:make_fast(errstr, errstr, msg, nil))
end
hook.add("Error", "basic error", basic_error)

local function default_dir_listing(req, res, dir, options)
	local elms = {}
	local files = {}
	
	dir = dir:path()
	
	for file in lfs.dir(dir) do
		if file ~= "." then
			local att = lfs.attributes(dir..file)
			att.isdir = att.mode == "directory"
			table.insert(files, {name=file, att = att})
		end
	end
	
	table.sort(files, function(a,b)
		if a.att.isdir and not b.att.isdir then
			return true
		elseif not a.att.isdir and b.att.isdir then
			return false
		end
		
		return a.name < b.name
	end)
	
	for k,v in pairs(files) do
		local classes = {v.att.mode}
		local size
		
		if not v.att.isdir then
			size = string.format("%s bytes", v.att.size)
			if v.att.permissions:match("x") then table.insert(classes, "executable") end
		end
		
		elms[k] = tags.tr
		{
			tags.td { class = "ls" }
			{
				tags.a { href = v.name..(v.att.isdir and "/" or "") } { tags.span { class = table.concat(classes, " ") } { v.name } }
			},
			tags.td { class = "ls ls-size" }
			{
				tags.span { size },
			}
		}
	end
	
	
	local content = tags.div { style = "width: 800px; background: rgba(255,255,255,0.0); color: white;" }
	{
		tags.style
		{[[
			a { text-decoration: none; }
			td.ls { padding-right: 50px; }
			td.ls-size { color: rgba(255,255,255,0.5); }
			.directory { color: #bbf; }
			.file { color: #fff; }
			.executable { color: #bfb; }
			.pipe { color: #fca; }
		]]},
		tags.table
		{
			table.unpack(elms)
		}
	}
	
	local view_path = options.view_path or req:path()
	template:make(view_path, view_path, "", content).to_response(res)
end
hook.add("ListDirectory", "default directory listing", default_dir_listing)

function line_from(file, line_targ)
	local ret = nil
	
	pcall(function()
		for line in io.lines(file) do 
			line_targ = line_targ - 1
			if line_targ == 0 then
				ret = line
				break
			end
		end
	end)
	
	return ret
end


local function basic_lua_error(err, trace, vars, args)
	local req = args[1]
	local res = args[2]
	
	fatal("%s: %s", err, trace or "no trace") -- print the raw uncleaned trace (as the cleaning stuff might omit important information...  for 99.99999% of cases though it should be fine.
	
	if trace then -- make the trace look pretty
		local blame = err:match("(.-:%d-:)")
		local atblame = blame == nil
		
		local split = trace:split("\n")
		-- table.remove(split, 1) -- remove the silly stack trace: text
		trace = {}
		
		for k,v in pairs(split) do
			local str = v:gsub("%[string \"(.-)\"%]", "%1")
			
			if blame and v:trim():starts_with(blame) then
				atblame = true -- we can start adding traces
			elseif str:trim():starts_with("inc/requesthooks.lua") then
				break -- after this is internal LuaFlare stuff
			end
			
			if atblame then
				table.insert(trace, str)
			end
		end
		
		trace = table.concat(trace, "\n")
	else
		trace = "stack trace unavailble"
	end
		
	local strvars = ""
	
	for k,v in pairs(vars) do
		strvars = strvars .. "(" .. type(v) .. ") " .. tostring(k) .. " = " .. tostring(v) .. "\n"
	end
	
	if res == nil or not res.clear then return end
	res:clear_content()
	res:set_status(500)
	
	local line_num = err:match(":(%d+)%:")
	local line
	local code = ""
	
	if line_num ~= nil then
		-- for the loadfile format, and loadstring format		
		local file = err:match("%[string \"(.-%.lua)") or err:match("(.-%.lua)")
		line_num = tonumber(line_num)
		
		line = line_from(file, line_num) or string.format("could not locate source for %s", file)
		line = line:trim("\t", "")
	else
		line = hook.call("LuaGetLine", err)
		
		if line == nil then
			line = "could not locate source"
		end
	end
	
	local done = {}
	
	if script.options["display-all-vars"] then
		for varname, var in pairs(vars) do
			local val = to_lua_value(var)
			local typ = type(var)
	
			if typ == "table" then
				local with = "{ -- " .. tostring(var)
				val = to_lua_table(var):gsub("{", with, 1)
			end
	
			code = code .. "local " .. varname .. " = " .. val .. "\n"
		end
	else
		for varname in line:gmatch("[A-z_][A-z0-9]*") do
			if vars[varname] ~= nil and not done[varname] then
				done[varname] = true
			
				local val = to_lua_value(vars[varname])
				local typ = type(vars[varname])
			
				if typ == "table" then
					local with = "{ -- " .. tostring(vars[varname])
					val = to_lua_table(vars[varname]):gsub("{", with, 1)
				end
			
				code = code .. "local " .. varname .. " = " .. val .. "\n"
			end
		end
	end
	
	local br_tag = tags.br
	if code == "" then br_tag = "" end
	
	local content = tags.div
	{
		tags.br,
		tags.h3 { "Variables" },
		tags.div {style = "font-family: monospace; margin-bottom: 5px;"}
		{
			code
		},
		tags.h3 { "Line" },
		tags.div {style = "font-family: monospace; margin-bottom: 5px;"}
		{
			line
		},
		tags.h3 { "Stack Trace" },
		tags.div
		{
			trace
		}
	}
	
	template:make("500 Internal Server Error", "500 Internal Server Error", err, content).to_response(res)
end
hook.add("LuaError", "basic error", basic_lua_error)
