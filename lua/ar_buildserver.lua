local socket = require("socket")

include("template_buildserver.lua")
-- /build/{repo}/status
-- /build/{repo}/update
-- /build/{repo}/state.png

local build_status = ""

local g_print = print
local function print(first, ...)
	build_status = build_status .. tostring(first) .. "\n"
	local args = {...}
	
	for i=1, #args do
		build_status = build_status .. tostring(args[i]) .. "\n"
	end
	
	g_print("buildserver: " .. tostring(first), ...) 
end

local function execute(command, error_fatal)
	print("+ " .. command)
	local ret, errcode = os.capture(command, true)
	build_status = build_status .. ret .. "\n"
	return errcode
end

local git = {}
git.clone = function(repo)
	return execute("git clone git@github.com:c0bra61/" .. repo .. ".git")
end
git.pull = function()
	execute("git fetch --all &&  git reset --hard origin/master")
end

local function on_update(req, res, project)
	g_print("update " .. project .. " by " .. req:client():getpeername())
	
	res:set_status(200)
	res:set_header("Content-Type", "text/plain")
	res:append("OK")
	res:send()
	
	-- okay, now we can continue with our operations, this may be a bit lengthy, so...
	local starttime = socket.gettime()
	
	-- check we have a dir
	if lfs.attributes("build_files", "mode") == nil then
		lfs.mkdir("build_files/")
	end
	
	
	local cd = lfs.currentdir()
		-- check a dir exists for the project
		if lfs.attributes("build_files/" .. project, "mode") == nil then
			lfs.chdir("build_files")
			git.clone(project)
			lfs.chdir(project)
		else
			lfs.chdir("build_files/" .. project)
			git.pull()
		end
		
		-- attempt the build
		local errcode = execute("./.buildserver")
	lfs.chdir(cd)
	
	if errcode == 0 then
		build_status = "OK\n" .. build_status
		
		if lfs.attributes("static/*/build", "mode") == nil then
			lfs.mkdir("static/*/build")
		end
		
		-- os.execute so not on logs, and copy the build, if it exists
		os.execute("mv 'build_files/" .. project .. "/build.zip' 'static/*/build/" .. project .. ".zip'")
		print("build passed")
	else
		build_status = "ERROR\n" .. build_status
		print("build failed")
	end
	
	
	
	local endtime = socket.gettime()
	local delta = endtime - starttime;
	print("completed in ".. math.Round(delta, 0.01) .." seconds")
	
	local file = io.open("build_files/build_" .. project .. ".log", "w")
	assert(file)
	file:write(build_status)
	file:close()
	
	build_status = ""
end

local function get_menu()
	local menu = {
		--"Main",
		--	{Home = "#"},
		--	{About = "#"},
		"Builds",
		--	{LuaPP = "#"},
		--	{LuaServer = "#"}
	}
	
	util.ItterateDir("build_files/", false, function(file)
		file = file:sub(("build_files/build_"):len() + 1, file:len() - 4)
		table.insert(menu, {[file] = "../" .. file .. "/"})
	end)
	
	return menu
end

local function on_status(req, res, project)
	local file = io.open("build_files/build_" .. project .. ".log")
	
	if not file then
		hook.Call("Error", {type = 404}, req, res)
		return
	end
	
	local contents = ""
	
	local is_ok = file:read("*l") == "OK"
	local line = file:read("*l") -- ignore the first line, OK or ERROR
	
	local already_command = false
	local function finish_command()
		if already_command then
			contents = contents .. "\t</ul>\n"
			already_command = false
		end
	end
	
	local function start_command(cmd)
		finish_command()
		already_command = true
		contents = contents .. "\t<ul class='commands'>\n\t\t<li class='command good'>"..cmd.."</li>\n"
	end
	
	contents = contents .. "<ul class='commands_root'>\n"
	while line ~= nil do
		local escaped = escape.html(line)
		
		if line:StartsWith("+ ") then
			start_command(escaped:sub(2))
		else
			contents = contents .. "\t\t<li class='commands'>" .. escaped .. "</li>\n"
		end
		
		line = file:read("*l")
	end
	
	if not is_ok then
		contents = contents:ReplaceLast("<li class='command good'>", "<li class='command bad'>")
	end
	
	finish_command()
	contents = contents .. "</ul>"
	
	local content = tags.div {
		tags.h2 { "Build result of " .. project },
		tags.img {src = "state.png"},
		tags.br,
		
		"Last successfull build: ",
		(function()
			local when = lfs.attributes("static/*/build/" .. project .. ".zip", "modification")
			
			if when == nil then return "never" end
			
			local day = os.date("*t", when).day
			local postfix
			
			if day > 10 and day < 20 then
				postfix = "th"
			elseif day % 10 == 1 then
				postfix = "st"
			elseif dat % 10 == 2 then
				postfix = "nd"
			elseif dat % 10 == 3 then
				postfix = "rd"
			else
				postfix = "th"
			end
			
			local str = os.date("%A, %d" .. postfix .. " %B, %Y", when)
			
			return tags.a {href = "/build/" .. project .. ".zip"}
			{
				str
			}
		end)(),
		
		tags.br, tags.br,
		tags.div -- {style = "overflow-x: scroll; white-space: nowrap; background-color: #333;"}
		{
			contents
		}
	}
	
	create_build_template("Build > " .. project, get_menu(), content).to_response(res)
	res:append("<!-- generated in " .. req:total_time() .. " seconds -->")
end

local function on_state(req, res, project)
	local file = io.open("build_files/build_" .. project .. ".log")
	
	if not file then
		hook.Call("Error", {type = 404}, req, res)
		return
	end
	
	local line =file:read("*l")
	
	if line == "OK" then
		res:set_file("resources/build_pass.png")
	else
		res:set_file("resources/build_fail.png")
	end
end

reqs.AddPattern("*", "/build/([A-z0-9\\-]+)/update", on_update)
reqs.AddPattern("*", "/build/([A-z0-9\\-]+)/status", on_status)
reqs.AddPattern("*", "/build/([A-z0-9\\-]+)/state%.png", on_state)

-- an alias to status
reqs.AddPattern("*", "/build/([A-z0-9\\-]+)/", on_status)
