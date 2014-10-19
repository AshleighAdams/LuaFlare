local hook = require("luaserver.hook")
local hosts = require("luaserver.hosts")
local scheduler = require("luaserver.scheduler")

local template = include("template-stats.lua")

local hits_data = {}
local hits = 0
local function increase_hit_counter()
	hits = hits + 1
end
hook.Add("Request", "statistics - hits", increase_hit_counter)

local load_data = {}
local load_max = 0

local warn_data = {}
local function on_warning(msg)
	local last = warn_data[#warn_data]
	if last and last.message == msg then
		last.count = last.count + 1
		last.time = os.time()
		return
	end
	table.insert(warn_data, {message = msg, time = os.time(), count = 1})
	
	if #warn_data > 5 then
		table.remove(warn_data, 1)
	end
end
hook.Add("Warning", "statistics - warnings", on_warning)

local function query()
	while true do
		do -- hits
			table.insert(hits_data, hits)
			if #hits_data > template.bars then table.remove(hits_data, 1) end
			hits = 0
		end
		
		do -- cpu
			if load_max == 0 then
				local p = assert(io.popen("grep processor /proc/cpuinfo | wc -l"), "can't detect number of processors")
				load_max = tonumber(p:read("*l"))
				p:close()
				
				assert(load_max, "can't detect number of processors (2)")
			end
			
			local uptime = assert(io.popen("uptime"), "can't find load average (no uptime)")
			local la = uptime:read("*l"):match("load average: ([%d.]+)")
			la = assert(tonumber(la or ""))
			
			table.insert(load_data, la)
			if #load_data > template.bars then table.remove(load_data, 1) end
		end
		
		coroutine.yield(60)
	end
end
scheduler.newtask("statistics query", query)

local function stats(req, res)
	
	template.make(req, res, {
		template.section("Generic"),
		template.graph("Hits", "/m", hits_data),
		template.graph("Load Average", "", load_data, load_max),
		
		template.section("Scheduler"),
		template.scheduler_info(),
		
		template.section("Warnings"),
		template.warnings(warn_data)
	})
end

hosts.developer:add("/stats", stats)
