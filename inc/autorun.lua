local reload_time = script.options["reload-time"] or 5 -- default to every 5 seconds

local time_table = {}
local includes_files = {}
local dependencies = {}
local function autorun(dir) expects "string"
	for file in lfs.dir(dir) do
		local filename = file
		file = dir .. file
		
		local modified = lfs.attributes(file, "modification")
		
		if modified ~= (time_table[file] or 0) then
			time_table[file] = modified
			
			if lfs.attributes(file, "mode") == "file" then
				if filename:StartsWith("ar_") and filename:EndsWith(".lua") then
					print("autorun: " .. file)
					
					for _, dep in ipairs(dependencies[file] or {}) do -- mark them as not required
						includes_files[dep] = (includes_files[dep] or 1) - 1
						time_table[dep] = lfs.attributes(dep, "modification")
					end
					
					dependencies[file] = include(file)
					
					for _, dep in ipairs(dependencies[file]) do -- remark as required (if an include was removed...)
						includes_files[dep] = (includes_files[dep] or 0) + 1
					end
				elseif includes_files[file] ~= nil and includes_files[file] > 0 then
					print("autorun dependency: " .. file)
					include(file)
				end
			elseif filename ~= "." and filename ~= ".." and lfs.attributes(file, "mode") == "directory" then
				autorun(file .. "/")
			end
			
		end
	end
end

local next_run = 0 -- just limit this to once every ~5 seconds, so under stress
                   -- it wont be slown down
local function reload_scripts()
	if util.time() < next_run then return end
	next_run = util.time() + reload_time
	
	autorun("lua/")
	
	for filename in lfs.dir("sites/") do
		local file = "sites/" .. filename
		
		if filename ~= "." and filename ~= ".." and lfs.attributes(file, "mode") == "directory" then
			if lfs.attributes(file .. "/lua", "mode") == "directory" then
				autorun(file .. "/lua/")
			end
		end
	end
end
hook.Add("ReloadScripts", "reload scripts", reload_scripts)
