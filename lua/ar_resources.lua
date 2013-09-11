require("lfs")

local function itterate_dir(dir, callback)
	assert(dir and callback)
	
	for file in lfs.dir(dir) do
		if lfs.attributes(dir .. file, "mode") == "file" then
			callback(dir .. file)
		elseif file ~= "." and file ~= ".." and lfs.attributes(dir .. file, "mode") == "directory" then
			itterate_dir(dir .. file .. "/", callback)
		end
	end
end

local function add_resource(filename)
	local pattern = filename:gsub("resources", "") -- remove the resources bit
	
	pattern = pattern:gsub("%%", "%%%%") -- escape %'s, and others
	
	pattern = pattern:gsub("%.", "%%.")
	pattern = pattern:gsub("%(", "%%(")
	pattern = pattern:gsub("%)", "%%)")
	pattern = pattern:gsub("%+", "%%+")
		
	local function serve_file(req, res)
		res:set_file(filename)
	end
	
	print("adding resource `" .. filename .. "' as `" .. pattern .. "'")
	reqs.AddPattern("*", pattern, serve_file)
end

itterate_dir("resources/", add_resource)
