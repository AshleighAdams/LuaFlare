local luaflare = require("luaflare")
local vfs = {}
vfs.mount_points = { "./" }

--[[
LuaFlare file structure:

/etc/luaflare/luaflare.cfg

]]

function vfs.locate(string path, boolean fallback = false)
	assert(path:sub(1,1) == "/")
	local selfdir = ""
	local info = debug.getinfo(2) -- caller info
	
	local source = info.source
	local root = luaflare.config_path
	
	assert(source:sub(1, root:len()) == root)
	
	local post = source:sub(root:len() + 1, -1)
	if post:starts_with("/sites/") then
		selfdir = root .. post:match("(/sites/.-)/")
	else
		selfdir = root
	end
	
	return selfdir .. path
end

function vfs.exists(string path)
end

function vfs.mount(string path)
end

function vfs.ls(string path, table options = {})
	local type = options.type
	local recursive = options.recursive
	local f = options.tester

	local ret = {}
	for file in lfs.dir(path) do
		if file ~= "." and file ~= ".." then
			local fullfile = string.format("%s/%s", path, file)
			local atts = lfs.attributes(fullfile)

			local add = true

			--- test the path against the filters
			if type and type ~= atts.mode then
				add = false
			end

			--- test against tester (along with what WOULD be, return nil for what would be)
			if f then
				local newadd = f(fullfile, options, atts, add)
				if newadd ~= nil then add = newadd end
			end

			-- finally, if we made it through everything, add the file
			if add then
				table.insert(ret, fullfile)
			end

			if recursive and atts.mode == "directory" then
				local toappend = vfs.ls(fullfile, options)
				for k,v in ipairs(toappend) do
					table.insert(ret, v)
				end
			end

		end
	end

	return ret
end

return vfs
