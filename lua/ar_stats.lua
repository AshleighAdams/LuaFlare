local hook = require("luaserver.hook")
local hosts = require("luaserver.hosts")
local scheduler = require("luaserver.scheduler")
local script = require("luaserver.util.script")

local template = include("template-stats.lua")



local function read_file_contents(file, f)
	local f = assert((f or io.open)(file, "r"))
	local ret = f:read("*a")
	f:close()
	return ret
end

local function get_proc_meminfo(pid)
	assert(pid)
	
	local pids = {pid}
	read_file_contents("pgrep -P "..pid, io.popen):gsub("(.-)\n",
		function(pid)
			if pid == "" then return end 
			table.insert(pids, pid) 
		end
	)
	
	local ret = {}
	
	for k, cpid in ipairs(pids) do
		local f = "/proc/"..cpid
		
		do
			local t = io.open(f.."/cmdline", "r")
			if not t then goto continue end
			t:close()
		end
		
		local task = {
			name = read_file_contents(f.."/comm"):match("(.+)\n"),
			mem = 0,
			modules = {},
			pid = cpid
		}
		
		local map = {}
		local meminfo = read_file_contents(f.."/maps")
		
		if meminfo == "" then goto continue end
		
		meminfo:gsub("(%x+)%-(%x+)%s-(.-)%s-(%x+)%s-(%x+:%x+)%s-(%x+)%s-(.-)\r?\n", 
			function(from, to, perms, offset, dev, inode, name)
				name = name:match("^%s*(.-)%s*$")
				
				map[name] = map[name] or {name = name, mem = 0, chunks = 0}
				local mod = map[name]
				
				local mem = tonumber(to, 16) - tonumber(from, 16)
				mod.chunks = mod.chunks + 1
				mod.mem = mod.mem + mem
				task.mem = task.mem + mem
			end
		)
		
		for k,v in pairs(map) do
			table.insert(task.modules, v)
		end
		table.sort(task.modules, function(a,b) return a.name < b.name end)
		table.insert(ret, task)
		::continue::
	end
	
	return ret
end



local hits_data = {}
local hits = 0
local function increase_hit_counter()
	hits = hits + 1
end
hook.add("Request", "statistics - hits", increase_hit_counter)

local load_data = {}
local load_max = 0

local memory_data = {}
local memory_max = 0
local memory_units = "ukn"

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
hook.add("Warning", "statistics - warnings", on_warning)

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
		
		do
			local p = assert(io.popen("cat /proc/meminfo"))
			local out = p:read("*a")
			p:close()
			
			if memory_max == 0 then
				local total, units = out:match("MemTotal:%s*(%d+)%s*(.-)\n")
				memory_max = assert(tonumber(total))
				memory_units = " " .. units
			end
			
			local aval = assert(out:match("MemAvailable:%s*(%d+)"))
			local free = memory_max - tonumber(aval)
			
			table.insert(memory_data, free)
			if #memory_data > template.bars then table.remove(memory_data, 1) end
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
		template.graph("Memory", memory_units, memory_data, memory_max),
		
		template.section("Memory Map"),
		template.mem_info(get_proc_meminfo(script.pid())),
		
		template.section("Scheduler"),
		template.scheduler_info(),
		
		template.section("Hooks"),
		template.hook_info(),
		
		template.section("Warnings"),
		template.warnings(warn_data)
	})
end

hosts.developer:add("/stats", stats)
