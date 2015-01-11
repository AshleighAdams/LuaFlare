local hook = require("luaflare.hook")
local hosts = require("luaflare.hosts")
local scheduler = require("luaflare.scheduler")
local script = require("luaflare.util.script")
local vfs = require("luaflare.virtualfilesystem")

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
local hits_max = 0
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

local path_statshits = vfs.locate("/.stats-hits.csv")
local path_statsload = vfs.locate("/.stats-load.csv")
local path_statsmem = vfs.locate("/.stats-mem.csv")
print(path_statsload)

function update_csv_files()
	local function write(file, first, data)
		local f = io.open(file, "w")
		f:write(first .. "\n")
		for k,v in ipairs(data) do
			f:write(string.format("%d, %f\n", v.time, v.data))
		end
		f:close()
	end
	
	write(path_statshits, "time, hits/m", hits_data)
	write(path_statsload, "time, load average", load_data)
	write(path_statsmem, "time, memory (MiB)", memory_data)
end

function load_csv_files()
	local function read(file, out_data)
		local f = io.open(file, "r")
		if not f then return end
		f:read("*l") -- remove the header line
		f:read("*a"):gsub("(.-), (.-)\n", function(a, b)
			table.insert(out_data, {time = tonumber(a), data = tonumber(b)})
		end)
		f:close()
	end
	
	read(path_statshits, hits_data)
	read(path_statsload, load_data)
	read(path_statsmem,  memory_data)
end
load_csv_files()

local function query()
	while true do
		do -- hits
			table.insert(hits_data, {time = os.time(), data = hits})
			if #hits_data > template.bars then table.remove(hits_data, 1) end
			
			
			local max = 1
			for k,v in pairs(hits_data) do
				if v.data > max then max = v.data end
			end
			hits_max = max
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
			
			table.insert(load_data, {time = os.time(), data = la})
			if #load_data > template.bars then table.remove(load_data, 1) end
		end
		
		do
			local p = assert(io.popen("cat /proc/meminfo"))
			local out = p:read("*a")
			p:close()
			
			if memory_max == 0 then
				local total, units = out:match("MemTotal:%s*(%d+)%s*(.-)\n")
				memory_max = assert(tonumber(total)) / 1024
				assert(units == "kB")
				memory_units = " " .. units
			end
			
			local aval = assert(out:match("MemAvailable:%s*(%d+)"))
			local free = memory_max - tonumber(aval) / 1024
			
			table.insert(memory_data, {time = os.time(), data = free})
			if #memory_data > template.bars then table.remove(memory_data, 1) end
		end
		
		update_csv_files()
		coroutine.yield(60)
	end
end
scheduler.newtask("statistics query", query)

local function stats(req, res)
	
	template.make(req, res, {
		template.section("Generic"),
		template.google_graph("Hits", "hits"),
		template.google_graph("Load Average", "load"),
		template.google_graph("Memory", "mem"),
		
		--template.graph("Hits", "/m", hits_data),
		--template.graph("Load Average", "", load_data, load_max),
		--template.graph("Memory", memory_units, memory_data, memory_max),
		
		template.section("Memory Map"),
		template.mem_info(get_proc_meminfo(script.pid())),
		
		template.section("Packages"),
		template.package_info(),
		
		template.section("Scheduler"),
		template.scheduler_info(),
		
		template.section("Hooks"),
		template.hook_info(),
		
		template.section("Warnings"),
		template.warnings(warn_data),
		
		template.section("Bootstrap Log"),
		template.bootstrap_info(),
	}, {hits_max = hits_max, load_max = load_max, memory_max = memory_max})
end

local function stats_hits_csv(req, res)
	res:set_file(path_statshits)
	res:set_header("Content-Type", "text/plain")
end

local function stats_load_csv(req, res)
	res:set_file(path_statsload)
	res:set_header("Content-Type", "text/plain")
end

local function stats_mem_csv(req, res)
	res:set_file(path_statsmem)
	res:set_header("Content-Type", "text/plain")
end

hosts.developer:add("/stats", stats)
hosts.developer:add("/stats/hits.csv", stats_hits_csv)
hosts.developer:add("/stats/load.csv", stats_load_csv)
hosts.developer:add("/stats/mem.csv",  stats_mem_csv)
