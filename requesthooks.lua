reqs = {}
reqs.PatternsRegistered = {}
reqs.FilesRegistered = {}

local function valid_host(target, what)
	target = target or ""
	return string.match(target, what) ~= nil
end

local function generate_host_patern(what)
	local pattern = what
	
	pattern = string.gsub(pattern, "%%", "%%%") -- this must be first...	
	pattern = string.gsub(pattern, "%.", "%%.") -- escape them
	pattern = string.gsub(pattern, "%(", "%%(")
	pattern = string.gsub(pattern, "%)", "%%)")
	pattern = string.gsub(pattern, "%+", "%%+")

	-- now, allow things like *domain.net, or *.domain.net, *domain.net*
	pattern = string.gsub(pattern, "*", ".+")
	
	print(what, "->", pattern)
	return pattern
end

local function generate_resource_patern(pattern)
	pattern = string.gsub(pattern, "*", ".+")
	return "__start__" .. pattern .. "__end__"
end

reqs.AddPattern = function(host, url, func)
	table.insert(reqs.PatternsRegistered, {host = generate_host_patern(host), url = generate_resource_patern(url), func = func})
end

reqs.OnRequest = function(request, response)
	local hits = {}
	
	for k,v in pairs(reqs.PatternsRegistered) do
		if valid_host(request.headers.Host, v.host) then
			local pattern = v.url -- there is a hack, so we detect the start end end of the string (not partial)
			local req_url = "__start__" .. request.url .. "__end__"
			local res = { string.match(req_url, pattern) }
			
			
			if #res ~= 0 then
				table.insert(hits, {hook = v, res = res})
			end
		end
	end
	
	if #hits == 0 then
		hook.Call("Error", {type = 404}, request, response)
	elseif #hits ~= 1 then
		hook.Call("Error", {type = 501, hits = hits}, request, response)
	else
		hits[1].hook.func(request, response, unpack(hits[1].res))
	end
end

hook.Add("Request", "default handler", reqs.OnRequest)


reqs.AddPattern("*", "/profile/(%d+)", function(request, response, id)
	print("/profile/" .. id)
end)
