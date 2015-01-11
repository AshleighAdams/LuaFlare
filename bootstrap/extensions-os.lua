local os_ex = {}

function os_ex.capture(cmd, opts)
	opts = opts or {stdout = true, stderr = true}
	if opts.stderr and opts.stdout then -- join them
		cmd = cmd .. "2>&1"
	elseif opts.stderr then -- swap 2 (err) for 1(out), and 1 to null
		cmd = cmd .. "2>&1 1>/dev/null"
	elseif opts.stdout then
		
	else -- assume both
		cmd = cmd .. "2>&1"
	end
	
	local f = assert(io.popen(cmd, "r"))
	local s = assert(f:read('*a'))
	local _, _, err_code = f:close()
	return s, err_code
end

local _platform = nil
local _version = 0
function os_ex.platform()
	if _platform then return _platform, _version end
	
	local ret = os.capture("uname -a")
	if ret == nil then
		_platform = "windows"
		_version = 6.1
	elseif ret:find("Linux") then
		_platform = "linux"
		_version = tonumber(table.concat({ret:match("(%d+%.%d+)%.(%d+)")}))
	elseif ret:find("Darwin") then
		_.platform = "mac" -- i hope mac version will work the same
		_version = tonumber(table.concat({ret:match("(%d+%.%d+)%.(%d+)")}))
	else
		_platform = "unknown"
		_version = "0"
	end
	
	return _platform, _version
end

return os_ex
