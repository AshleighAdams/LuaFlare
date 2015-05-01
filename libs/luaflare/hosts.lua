local hosts = {} -- make require("luaflare.hosts") like
hosts.hosts = {}
hosts.upgrades = {}
hosts.host_meta = {}
hosts.host_meta.__index = hosts.host_meta

local hook = require("luaflare.hook")
local escape = require("luaflare.util.escape")

local function generate_host_patern(what) -- TODO: use pattern_escape, can't replace the *
	local pattern = escape.pattern(what)
	
	pattern = string.gsub(pattern, "%%%*", ".*")
	pattern = string.gsub(pattern, "%%%~", ".+")
	pattern = string.gsub(pattern, "%%%+", "[^%%.]+")
	
	return "^" .. pattern .. "$"
end
local function generate_resource_patern(string pattern)
	pattern = string.gsub(pattern, "*", "[^/]*")
	return "^" .. pattern .. "$"
end


function hosts.get(string host, options)
	if hosts.hosts[host] then return hosts.hosts[host] end
	local obj = setmetatable({
		pattern = generate_host_patern(host),
		host = host,
		pages = {},
		page_patterns = {},
		options = options
	}, hosts.host_meta)
	
	hosts.hosts[host] = obj
	return obj
end

function hosts.match(string hosts_list) -- takes a comma-delimitered list of hosts, will return the first match (any if none)
	local split = hosts_list:split(",")
	
	for k, host in pairs(split) do
		local site, err, reason = hosts.match_single(host:trim())
		if site == nil then
			return site, err, reason
		elseif site == hosts.any then
			-- continue
		else
			--success!
			return site, err, reason
		end
	end
	
	return hosts.any
end

function hosts.match_single(string host) -- takes a single host
	-- so the pattern "*.domain.com" matches "domain.com"
	-- note that "+.domain.com" does not match "domain.com"
	host = "." .. host
	
	local hits = {}
	
	for k,v in pairs(hosts.hosts) do
		if k ~= "*" and host:match(v.pattern) then
			table.insert(hits, v)
		end
	end
	
	local c = #hits
	
	if c == 0 then
		return hosts.any
	elseif c == 1 then
		return hits[1]
	else
		local err
		
		local conflicts = {}
		for k,v in ipairs(hits) do
			conflicts[k] = v.host
		end
		
		if #hits == 2 then
			err = "Host conflict between: " .. table.concat(conflicts, " and ")
		else
			err = "Host conflict between: " .. table.concat(conflicts, ", "):gsub(", (.-)$", ", and %1")
		end
		
		return nil, 500, err
	end
end

function hosts.host_meta::addpattern(string pattern, function callback, string method = "GET")
	local page = {
		pattern = generate_resource_patern(pattern),
		original_pattern = pattern,
		callback = callback,
		method = method
	}
	self.page_patterns[pattern] = page
end

function hosts.host_meta::add(string url, function callback, string method = "GET")
	local page_root = self.pages[url]
	if not page_root then
		page_root = {}
		self.pages[url] = page_root
	end

	local page = {
		url = url,
		callback = callback,
		method = method
	}
	
	page_root[method] = page
end

hosts.method_synoms = {
	HEAD = {
		GET = true
	}
}

function hosts.host_meta::match(string path, string method = "GET")
	local hits = {}
	
	if self.pages[path] then -- should we test against patterns too?
		for k,v in pairs(self.pages[path]) do
			table.insert(hits, {page = v, args = {path}})
		end
	end
	
	for k,page in pairs(self.page_patterns) do
		local args = table.pack(path:match(page.pattern))
		if #args ~= 0 then
			table.insert(hits, {page = page, args = args})
		end
	end
	
	local hits_count = #hits
	
	-- let's test the methods
	if hits_count ~= 0 then
		local methods = {}
		for i = #hits, 1 do
			local hit = hits[i]
			local page = hit.page
			
			-- update the list of valid methods
			if not methods[page.method] then
				methods[page.method] = true
				table.insert(methods, page.method)
			end
			
			-- we don't want other methods in the list...
			if method ~= page.method then
				local synoms = hosts.method_synoms[method]
				if not synoms or not synoms[page.method] then
					table.remove(hits, i)
				end
			end
		end
		-- update this var, and if we no longer have a match, throw an error
		hits_count = #hits
		
		if hits_count == 0 then
			local valid_methods = table.concat(methods, ", ")
			return nil, nil, 405, string.format("The method %s is not valid for this resource.  Valid methods are: %s.", method, valid_methods), {Allow = valid_methods}
		end
	end
	
	if hits_count == 0 then
		return nil, nil, 404
	elseif hits_count == 1 then
		return hits[1].page, hits[1].args
	else
		local function func_string(func) expects("function")
			local info = debug.getinfo(func)
			return string.format("%s @ %s:%d", info.name or "function", info.source or "unknown", info.linedefined or -1)
		end
		local lines = {"The following hooks are conflicted with this request:", ""}
		
		for k,v in pairs(hits) do
			local line = string.format("%s as %s with arguments %s", 
				v.page.original_pattern, func_string(v.page.callback), table.concat(v.args, ", "))
			table.insert(lines, line)
		end
		
		local lines = table.concat(lines, "\n")
		warn("%s", lines)
		
		return nil, nil, 500, lines
	end
end

function hosts.upgrade_request(request, response) -- check for upgrade
	local headers = request:headers()
	if not headers.Connection
	or not headers.Upgrade
	or not headers.Connection:lower():match("upgrade")
	then
		return false
	end

	local ug = (request:headers().Upgrade or ""):lower()
	local f = hosts.upgrades[ug]
	
	if not f then
		response:halt(404, "Upgrade not found: " .. ug)
	else
		f(request, response)
	end
	
	return true
end

function hosts.process_request(req, res)
	-- check to see if we should upgrade, and if we did, return
	if hosts.upgrade_request(req, res) then return end
	
	local host, errcode, errstr = hosts.match(req:host())
	if not host then -- conflict between hosts
		warn(errstr)
		res:halt(errcode, errstr)
		return
	end
	
	local page, args, errcode, errstr, headers = host:match(req:path(), req:method())
	
	-- failed, try wildcard
	if not page and errcode == 404 and (not host.options or not host.options.no_fallback) then
		page, args, errcode, errstr, headers = hosts.any:match(req:path(), req:method())
	end
	
	
	if headers then
		for k,v in pairs(headers) do
			res:set_header(k, v)
		end
	end
	
	if not page then
		assert(errcode)
		res:halt(errcode, errstr)
		return
	end
	
	page.callback(req, res, table.unpack(args))
end
hook.add("Request", "default", hosts.process_request)

hosts.any = hosts.get("*")
hosts.developer = hosts.any

-- backwards compatability
local reqs_fallback = {
	AddPattern = function(host, url, func)
		hosts.get(host):add(url, func)
	end,
	Upgrades = hosts.upgrades
}

_G.reqs = setmetatable({}, {__index = function(self, k)
	warn("reqs." .. k .. " has been depricated! Use hosts.\n" .. debug.traceback("", 2))
	return reqs_fallback[k]
end})

return hosts
