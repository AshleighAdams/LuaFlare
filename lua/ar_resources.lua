require("lfs")
local static_dir = "static/"

local function itterate_dir(dir, callback, ...)
	assert(dir and callback)
	
	for file in lfs.dir(dir) do
		if lfs.attributes(dir .. file, "mode") == "file" then
			callback(dir .. file, ...)
		elseif file ~= "." and file ~= ".." and lfs.attributes(dir .. file, "mode") == "directory" then
			itterate_dir(dir .. file .. "/", callback, ...)
		end
	end
end

local function add_resource(filename, host)
	pattern = filename:gsub(static_dir .. pattern_escape(host), "") -- remove our dir
	pattern = pattern_escape(pattern)
		
	local function serve_file(req, res)
		res:set_file(filename)
	end
	
	--print("adding resource `" .. filename .. "' as `" .. pattern .. "'")
	print("//" .. host .. pattern .. " -> " .. filename)
	reqs.AddPattern(host, pattern, serve_file)
end

for folder in lfs.dir(static_dir) do
	if folder ~= "." and folder ~= ".." and lfs.attributes(static_dir .. folder, "mode") == "directory" then
		itterate_dir(static_dir .. folder .. "/", add_resource, folder)
	end
end
