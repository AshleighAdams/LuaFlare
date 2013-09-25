local configor = require("configor")
local json = require("dkjson")
local ssl = require("ssl")
ssl.https = require("ssl.https")

function pushover(request) -- https://github.com/sweetfish/pushover-lua/blob/master/pushover.lua
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
	end
	
	local obj = json.decode(res)
	if obj.status ~= 1 then
		local errstr = "Error from pushover: " .. tostring(res)
		return false, errstr
	end
	
	return true
end

-- ensure that the options exist
local ops = configor.loadfile(script.local_path("options.cfg.secret"), true)	
if ops:children().pushover == nil then
	ops.pushover.token:set_value("enter token")
	ops.pushover.user:set_value("enter user key")
	configor.savefile(ops, script.local_path("options.cfg.secret"))
end

local function onbuild(req, project, success, buildtime, shell)
	local payload = json.decode(req:post_data().payload)
	
	local commit = payload.head_commit
	local ops = configor.loadfile(script.local_path("options.cfg.secret"))
		
	local push = {
		token = ops.pushover.token:data(),
		user = ops.pushover.user:data(),
		timestamp = os.time()
	}
	
	if not success then
		push.title = string.format("%s build failed", project)
		push.priority = 2
		push.retry = 60 * 2 -- 2min
		push.expire = 60 * 60 * 1 -- 1 hour
		push.message = string.format("%s pushed to %s:\n%s\nBuild failed", commit.author.name, project, commit.message)
	else
		push.title = string.format("%s build succeded", project)
		push.message = string.format("%s pushed to %s:\n%s\nSuccessfully built in %f seconds.", commit.author.name, project, commit.message, 
			math.Round(buildtime, 0.01))
	end
	
	local suc, err = pushover(push)
	if not suc then print(err) end
end

hook.Add("BuildServer.Built", "pushover", onbuild)