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
			lfs.chdir("build_files/" .. project)
		else
			lfs.chdir("build_files/" .. project)
			git.pull()
		end
		
		-- attempt the build
		local errcode = execute("./.buildserver")
	lfs.chdir(cd)
	
	if errcode == 0 then
		build_status = "OK\n" .. build_status
		
		if lfs.attributes("static/*/builds", "mode") == nil then
			lfs.mkdir("static/*/builds")
		end
		
		-- os.execute so not on logs, and copy the build, if it exists
		os.execute("mv 'build_files/" .. project .. "/build.zip' 'static/*/builds/" .. project .. ".zip'")
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

local function on_status(req, res, project)
	local file = io.open("build_files/build_" .. project .. ".log")
	
	if not file then
		hook.Call("Error", {type = 404}, req, res)
		return
	end
	
	local contents = ""
	
	local line = file:read("*l")
	line = file:read("*l") -- ignore the first line, OK or ERROR
	while line ~= nil do
		
		local escaped = escape.html(line)
		
		if line:StartsWith("+ ") then
			contents = contents .. "<b>" .. escaped:sub(2) .. "</b><br/>\n"
		else
			contents = contents .. escaped .. "<br/>\n"
		end
		
		line = file:read("*l")
	end
	
	
	
	local menu = {
		"Main",
			{Home = "#"},
			{About = "#"},
		"Builds",
			{LuaPP = "#"},
			{LuaServer = "#"}
	}
	
	local content = tags.div {
		tags.h2 { "Build result of " .. project },
		tags.img {src = "state.png"},
		tags.p {style = "font-family: monospace;"}
		{
			contents
		}
	}
	
	create_build_template("Build > " .. project, menu, content).to_response(res)
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
