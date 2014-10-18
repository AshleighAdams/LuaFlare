require("lfs")
local mimetypes = require("mimetypes")

local static_dir = "static/"
local count = 0

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

local Months = {Jan=1,Feb=2,Mar=3,Apr=4,May=5,Jun=6,Jul=7,Aug=8,Sep=9,Oct=10,Nov=11,Dec=12}

local function add_resource(filename, host)
	pattern = filename:Replace(static_dir .. host, "") -- remove our dir
	pattern = escape.pattern(pattern)
		
	local function serve_file(req, res)
		local ifmod = req:headers()["If-Modified-Since"]
		local ours = lfs.attributes(filename, "modification")
		
		if ifmod then
			local pattern = "%a+, (%d+) (%a+) (%d+) (%d+):(%d+):(%d+) (%a+)"
			local day, month, year, hour, min, sec, tz = ifmod:match(pattern)

			month = Months[month]
			local theirs = os.time({tz=tz,day=day,month=month,year=year,hour=hour,min=min,sec=sec})
			if theirs and ours <= theirs then
				res:set_header("Content-Type", mimetypes.guess(filename))
				res:set_status(304)
				return
			end
		end
		
		local format = "%a, %d %b %Y %X UTC"
		local timestring = os.date(format, ours)
		local expires = os.date(format, os.time() + 1000) -- 1k seconds
		
		res:set_header("Last-Modified", timestring)
		res:set_header("Expires", expires)
		res:set_file(filename)
	end
	
	--print("adding resource `" .. filename .. "' as `" .. pattern .. "'")
	--print("//" .. host .. pattern .. " -> " .. filename)
	count = count + 1
	hosts.get(host):add(pattern, serve_file)
end

-- load global static dir
for folder in lfs.dir(static_dir) do
	if folder ~= "." and folder ~= ".." and lfs.attributes(static_dir .. folder, "mode") == "directory" then
		itterate_dir(static_dir .. folder .. "/", add_resource, folder)
	end
end

print(string.format("%d static resources registered (%s)", count, "N/A"))
count = 0

--load sites static's dir

for filename in lfs.dir("sites/") do
	local file = "sites/" .. filename .. "/static/"
	static_dir = file
	
	if filename ~= "." and filename ~= ".." and lfs.attributes(file, "mode") == "directory" then
		
		for folder in lfs.dir(file) do
			if folder ~= "." and folder ~= ".." and lfs.attributes(file .. folder, "mode") == "directory" then
				itterate_dir(file .. folder .. "/", add_resource, folder)
			end
		end
		
		print(string.format("%d static resources registered (%s)", count, filename))
		count = 0
		
	end
	
end


