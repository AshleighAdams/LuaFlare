reqs = {}
reqs.PatternsRegistered = {}
reqs.FilesRegistered = {}

local function valid_host(target, what)
	target = target or "main"
	return string.match(target, what) ~= nil
end

local function generate_host_patern(what) -- TODO: use pattern_escape, can't replace the *
	local pattern = what
	
	-- TODO: should these even be here? other than the . and * replacement
	pattern = string.gsub(pattern, "%%", "%%%") -- this must be first...	
	pattern = string.gsub(pattern, "%.", "%%.") -- escape them
	pattern = string.gsub(pattern, "%(", "%%(")
	pattern = string.gsub(pattern, "%)", "%%)")
	pattern = string.gsub(pattern, "%+", "%%+")

	-- now, allow things like *domain.net, or *.domain.net, *domain.net*
	pattern = string.gsub(pattern, "*", ".+")
	
	return pattern
end

local function generate_resource_patern(pattern)
	--pattern = string.gsub(pattern, "*", ".+")
	-- 0 to '/' - 1, '/' + 1 to '\' - 1, '\' + 1 to 255
	-- 0x2f == '/'; 0x5c == '\\'
	-- [\x00-\x2e\x30-\x5b\x5d-\xff]+
	-- how to gsub this?
	-- [%w%s!-.:-@%%%]%[-\xff]-
	-- [%%w%%s!-.:-@%%%%%%]%%[-\xff]-
	pattern = string.gsub(pattern, "*", "[%%w%%s!-.:-@%%%%%%]%%[-\xff]-")
	return "^" .. pattern .. "$"
end

reqs.AddPattern = function(host, url, func)
	host = generate_host_patern(host)
	url = generate_resource_patern(url)
	
	for k, v in ipairs(reqs.PatternsRegistered) do -- already exists, overwrite it and warn
		if v.host == host and v.url == url then
			v.func = func
			return
		end
	end
	
	table.insert(reqs.PatternsRegistered, {host = host, url = url, func = func})
end

reqs.Upgrades = {}

local function func_string(func) expects("function")
	local info = debug.getinfo(func)
	return string.format("%s @ %s:%d", info.name or "function", info.source or "unknown", info.linedefined or -1)
end

reqs.OnRequest = function(request, response)
	local hits = {}
	local req_url = request:url()
	
	if request:headers().Connection and request:headers().Connection:match("Upgrade") ~= nil then
		local ug = (request:headers().Upgrade or ""):lower()
		local f = reqs.Upgrades[ug]
		
		if not f then
			response:halt(500, "Invalid upgrade: " .. ug)
			return
		end
		
		f(request, response)
		return
	end
	
	for k,v in ipairs(reqs.PatternsRegistered) do
		if valid_host(request:headers().Host, v.host) then
			local pattern = v.url -- there is a hack, so we detect the start end end of the string (not partial)
			local res = { string.match(req_url, pattern) }
			
			if #res ~= 0 then
				table.insert(hits, {hook = v, res = res})
			end
		end
	end
	
	if #hits == 0 then
		response:halt(404)
	elseif #hits ~= 1 then
		local lines = {"The following hooks are conflicted with this request:", ""}
		for k,v in pairs(hits) do
			local line = string.format("%s as %s with arguments %s", 
				v.hook.url, func_string(v.hook.func), table.concat(v.res, ", "))
			table.insert(lines, line)
		end
		local lines = table.concat(lines, "\n")
		warn(lines)
		response:halt(409 --[[conflict]], lines)
	else
		hits[1].hook.func(request, response, unpack(hits[1].res))
	end
end
hook.Add("Request", "default", reqs.OnRequest)
