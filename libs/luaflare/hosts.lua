local hosts = {} -- make require("luaflare.hosts") like
hosts.hosts = {}
hosts.upgrades = {}
hosts.host_meta = {}
hosts.host_meta.__index = hosts.host_meta

local hook = require("luaflare.hook")

local function generate_host_patern(what) -- TODO: use pattern_escape, can't replace the *
	local pattern = what
	
	-- TODO: should these even be here? other than the . and * replacement
	pattern = string.gsub(pattern, "%%", "%%%") -- this must be first...	
	pattern = string.gsub(pattern, "(%.%-)", "%%%1") -- escape them
	--pattern = string.gsub(pattern, "%(", "%%(")
	--pattern = string.gsub(pattern, "%)", "%%)")
	--pattern = string.gsub(pattern, "%+", "%%+")

	-- now, allow things like *domain.net, or *.domain.net, *domain.net*
	pattern = string.gsub(pattern, "*", "[.]*")
	pattern = string.gsub(pattern, "~", "[.]+")
	pattern = string.gsub(pattern, "+", "[^%.]+")
	
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
		pages = {},
		page_patterns = {},
		options = options
	}, hosts.host_meta)
	
	hosts.hosts[host] = obj
	return obj
end

function hosts.match(string host)
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
		
		if #hits == 2 then
			err = "Host conflict between: " .. table.concat(hits, " and ")
		else
			err = "Host conflict between: " .. table.concat(hits, ", "):gsub(", (.-)$", ", and %1")
		end
		
		return nil, err
	end
end

function hosts.host_meta::addpattern(string pattern, function callback)
	local page = {
		pattern = generate_resource_patern(pattern),
		original_pattern = pattern,
		callback = callback
	}
	self.page_patterns[pattern] = page
end

function hosts.host_meta::add(string url, function callback)
	local page = {
		url = url,
		callback = callback
	}
	self.pages[url] = page
end

function hosts.host_meta::match(string url)
	local hits = {}
	
	if self.pages[url] then -- should we test against patterns too?
		table.insert(hits, {page = self.pages[url], args = {url}})
	end
	
	for k,page in pairs(self.page_patterns) do
		local args = table.pack(url:match(page.pattern))
		if #args ~= 0 then
			table.insert(hits, {page = page, args = args})
		end
	end
	
	if #hits == 0 then
		return nil, nil, 404
	elseif #hits == 1 then
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
		warn(lines)
		
		return nil, nil, 409, lines
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
	
	local host, err = hosts.match(req:host())
	if not host then -- conflict between hosts
		warn(err)
		return res:halt(409, err)
	end
	
	local page, args, errcode, errstr = host:match(req:url())
	
	-- failed, try wildcard
	if not page and errcode == 404 and (not host.options or not host.options.no_fallback) then
		page, args, errcode, errstr = hosts.any:match(req:url())
	end
	
	if not page then
		assert(errcode)
		return res:halt(errcode, errstr)
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
