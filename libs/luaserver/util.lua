local util = {
	canonicalize_header = require("luaserver.util.canonicalize_header"),
	escape              = require("luaserver.util.escape"),
	script              = require("luaserver.util.script"),
	stack               = require("luaserver.util.stack"),
	translate_luacode   = require("luaserver.util.translate_luacode"),
}

do
	local socket = require("socket")
	local posix = require("posix")
	
	function util.time()
		return socket.gettime()
	end

	function util.ItterateDir(dir, recursive, callback, ...) expects("string", "boolean", "function")
		assert(dir and recursive ~= nil and callback)
	
		for file in lfs.dir(dir) do
			if lfs.attributes(dir .. file, "mode") == "file" then
				callback(dir .. file, ...)
			elseif recursive and file ~= "." and file ~= ".." and lfs.attributes(dir .. file, "mode") == "directory" then
				itterate_dir(dir .. file .. "/", recursive, callback, ...)
			end
		end
	end

	function util.DirExists(dir) expects "string"
		return lfs.attributes(dir, "mode") == "directory"
	end

	function util.Dir(base_dir, recursive) expects "string"
		local ret = {}
	
		local itt_dir = function(dir)
			for filename in lfs.dir(dir) do
				if filename ~= "." and filename ~= ".." then
			
					local file = dir .. file
					if util.DirExists(file) then
						table.insert(ret, {name=file .. "/", dir=true})
						if recursive then itt_dir(file .. "/") end
					else
						table.insert(ret, {name=file, dir=false})
					end
				
				end
			end
		end
	
		itt_dir(base_dir)
		return ret
	end

	function util.EnsurePath(path) expects "string" -- false = already exists, true = didn't
		if util.DirExists(path) then return false end
	
		local split = path:Split("/")
		local cd = ""
	
		for k,v in ipairs(split) do
			cd = cd .. v .. "/"
		
			if not util.DirExists(path) then
				assert(lfs.mkdir(cd))
			end
		end
	
		return true
	end

end

return util
