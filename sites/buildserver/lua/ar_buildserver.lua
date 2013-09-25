include("template_buildserver.lua")
local ssl = require("ssl")
ssl.https = require("ssl.https")
local json = require("dkjson")
local configor = require("configor")

function pushover( request ) -- https://github.com/sweetfish/pushover-lua/blob/master/pushover.lua
	local pushover_url = "https://api.pushover.net/1/messages.json"
	local data_str = {}
	for k,v in pairs(request) do
		table.insert(data_str, tostring(k) .. "=" .. tostring(v))
	end
	data_str = table.concat(data_str, "&")
	local res, code, headers, status = ssl.https.request(pushover_url, data_str)
	if (code ~= 200) then
		local errstr = "Error while sending request. Status code: " .. tostring(code) .. ", Body: " .. tostring(res)
		return false, errstr
	elseif (res ~= '{"status":1}') then
		local errstr = "Error from pushover: " .. tostring(res)
		return false, errstr
	end
	return true
end

local build_status = "" -- the current status of a build

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
	g_print("update " .. project .. " by " .. req:peer())
	
	local payload = json.decode(req:post_data().payload)
	
	if payload ~= nil then
		res:set_status(200)
		res:set_header("Content-Type", "text/plain")
		res:append("OK")
		res:send()
	else
		res:set_status(400)
		res:set_header("Content-Type", "text/plain")
		res:append("NO")
		res:send()
	end
		
	-- check we have a dir
	if lfs.attributes(script.local_path("build_files"), "mode") == nil then
		lfs.mkdir(script.local_path("build_files/"))
	end
	
	local cd = lfs.currentdir()
		-- check a dir exists for the project
		if lfs.attributes(script.local_path("build_files/" .. project), "mode") == nil then
			lfs.chdir(script.local_path("build_files"))
			git.clone(project)
			lfs.chdir(project)
		else
			lfs.chdir(script.local_path("build_files/" .. project))
			git.pull()
		end
		
		local starttime = util.time()
		-- attempt the build
		local errcode = execute("./.buildserver")
	lfs.chdir(cd)
	
	if errcode == 0 then
		build_status = "OK\n" .. build_status
		
		if lfs.attributes(script.local_path("static/*/build"), "mode") == nil then
			lfs.mkdir(script.local_path("static/*/build"))
		end
		
		-- os.execute so not on logs, and copy the build, if it exists
		local from = script.local_path("build_files/" .. project .. "/build.zip")
		local to = script.local_path("static/*/build/" .. project .. ".zip")
		os.execute("mv " .. escape.argument(from) .. " " .. escape.argument(to))
		print("build passed")
	else
		build_status = "ERROR\n" .. build_status
		print("build failed")
	end
	
	local delta = util.time() - starttime;
	print("completed in ".. math.Round(delta, 0.01) .." seconds")
	
	local file = io.open(script.local_path("build_files/build_" .. project .. ".log"), "w")
	assert(file)
	file:write(build_status)
	file:close()
	
	build_status = ""
	
	
	local commit = payload.head_commit
	local ops = configor.loadfile(script.local_path("options.cfg.secret"))
		
	local push = {
		token = ops.pushover.token:data(),
		user = ops.pushover.user:data(),
		timestamp = os.time()
	}
	
	if errcode == 0 then
		push.title = string.format("%s build failed", project)
		push.priority = 2
		push.retry = 60 * 2 -- 2min
		push.expire = 60 * 60 * 1 -- 1 hour
		push.message = string.format("%s pushed to %s:\n%s\nBuild failed", commit.author.name, project, commit.message)
	else
		push.title = string.format("%s build succeded", project)
		push.message = string.format("%s pushed to %s:\n%s\nSuccessfully built in %i seconds.", commit.author.name, project, commit.message, 
			math.Round(delta, 0.01))
	end
	
	local suc, err = pushover(push)
	if not suc then print(err) end
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
	
	util.ItterateDir(script.local_path("build_files/"), false, function(file)
		file = file:sub(script.local_path("build_files/build_"):len() + 1, file:len() - 4)
		table.insert(menu, {[file] = "../../" .. file .. "/"})
	end)
	
	return menu
end

local function on_status(req, res, project, branch)
	local file = io.open(script.local_path("build_files/build_" .. project .. ".log"))
	
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
			local when = lfs.attributes(script.local_path("static/*/build/" .. project .. ".zip"), "modification")
			
			if when == nil then return "never" end
			
			local day = os.date("*t", when).day
			local postfix
			
			if day >= 10 and day <= 20 then
				postfix = "th"
			elseif day % 10 == 1 then
				postfix = "st"
			elseif day % 10 == 2 then
				postfix = "nd"
			elseif day % 10 == 3 then
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

local function on_state(req, res, project, branch)
	local file = io.open(script.local_path("build_files/build_" .. project .. ".log"))
	
	if not file then
		hook.Call("Error", {type = 404}, req, res)
		return
	end
	
	local line = file:read("*l")
	
	if line == "OK" then
		res:set_file(script.local_path("resources/build_pass.png"))
	else
		res:set_file(script.local_path("resources/build_fail.png"))
	end
end

local function redirect_master(req, res)
	res:set_status(303) -- redirect, the proper way
	res:set_header("Location", req:url() .. "master/status")
end

reqs.AddPattern("*", "/build/(*)/update", on_update)
reqs.AddPattern("*", "/build/(*)/(*)/status", on_status)
reqs.AddPattern("*", "/build/(*)/(*)/state%.png", on_state)
reqs.AddPattern("*", "/build/*/", redirect_master)

-- ensure that the options exist
local ops = configor.loadfile(script.local_path("options.cfg.secret"), true)	
if ops:children().pushover == nil then
	ops.pushover.token:set_value("enter token")
	ops.pushover.user:set_value("enter user key")
	configor.savefile(ops, script.local_path("options.cfg.secret"))
end