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
	pattern = string.gsub(pattern, "*", ".+")
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

reqs.OnRequest = function(request, response)
	local hits = {}
	local req_url = request:url()
	
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
		hook.Call("Error", {type = 404}, request, response)
	elseif #hits ~= 1 then
		hook.Call("Error", {type = 501, message = "page clash"}, request, response)
	else
		hits[1].hook.func(request, response, unpack(hits[1].res))
	end
end
hook.Add("Request", "default handler", reqs.OnRequest)
