local util = {}

util.cannon_headers      = require("luaflare.util.canonicalize-header")
util.escape              = require("luaflare.util.escape")
util.script              = require("luaflare.util.script")
util.stack               = require("luaflare.util.stack")
util.translate_luacode   = require("luaflare.util.translate_luacode")

do
	local socket = require("socket")
	local posix = require("posix")
	
	function util.time()
		return socket.gettime()
	end

	function util.iterate_dir(dir, recursive, callback, ...) expects("string", "boolean", "function")
		assert(dir and recursive ~= nil and callback)
	
		for file in lfs.dir(dir) do
			if lfs.attributes(dir .. file, "mode") == "file" then
				callback(dir .. file, ...)
			elseif recursive and file ~= "." and file ~= ".." and lfs.attributes(dir .. file, "mode") == "directory" then
				itterate_dir(dir .. file .. "/", recursive, callback, ...)
			end
		end
	end
	
	function util.dir_exists(dir) expects "string"
		return lfs.attributes(dir, "mode") == "directory"
	end
	
	function util.dir(base_dir, recursive) expects "string"
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

	function util.ensure_path(path) expects "string" -- false = already exists, true = didn't
		if util.dir_exists(path) then return false end
	
		local split = path:Split("/")
		local cd = ""
	
		for k,v in ipairs(split) do
			cd = cd .. v .. "/"
		
			if not util.dir_exists(path) then
				return lfs.mkdir(cd)
			end
		end
	
		return true
	end
	
	
	util.ItterateDir = function(...)
		warn("util.ItterateDir has been renamed to util.iterate_dir")
		return util.iterate_dir(...)
	end
	util.DirExists = function(...)
		warn("util.DirExists has been renamed to util.dir_exists")
		return util.dir_exists(...)
	end
	util.Dir = function(...)
		warn("util.Dir has been renamed to util.dir")
		return util.dir(...)
	end
	util.EnsurePath = function(...)
		warn("util.EnsurePath has been renamed to util.ensure_path")
		return util.ensure_path(...)
	end
end

return util
