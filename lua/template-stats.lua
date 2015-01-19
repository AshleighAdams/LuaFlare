local tags = require("luaflare.tags")
local scheduler = require("luaflare.scheduler")
local script = require("luaflare.util.script")
local hook = require("luaflare.hook")
local slug = require("luaflare.util.slug")

local template = {}
template.barwidth = 1;
template.graphwidth = 800;
template.bars = template.graphwidth / template.barwidth

function template.make(req, res, contents, info)
	tags.html
	{
		tags.head
		{
			tags.title { "LuaFlare Statistics" },
			tags.script { src = "//www.google.com/jsapi" },
			tags.script { src = "//ajax.googleapis.com/ajax/libs/jquery/2.1.1/jquery.min.js" },
			tags.script { src = "/stats/jquery.csv-0.71.min.js" },
			tags.script
			{
				[[
				google.load("visualization", "1", {packages:["corechart"]});
				google.setOnLoadCallback(draw_chart);
				
				function update_chart(url, id, max)
				{
					$.get(url, function(rawdata)
					{
						var array_data = $.csv.toArrays(rawdata, {onParseValue: $.csv.hooks.castToScalar});
						var data = new google.visualization.arrayToDataTable(array_data);
						
						var view = new google.visualization.DataView(data);
						view.setColumns([{
							type: 'datetime',
							label: 'time',
							calc: function (dt, row) {
								var ret = new Date(dt.getValue(row, 0)*1000);
								return {v:ret, f: ret.toString()};
							}
						},1]);
						
						var options = {
							title: "",
							vAxis: {title: data.getColumnLabel(1), viewWindow: {min: 0}, minValue: 0, maxValue: max},
							hAxis: {format: "HH:mm"},
							legend: "none",
							curveType: "function",
							lineWidth: 0,
						};
						
						var chart = new google.visualization.AreaChart(document.getElementById(id));
						chart.draw(view, options);
					})
				}
				
				function draw_chart()
				{
					update_chart("/stats/hits.csv", "graph-hits", ]]..info.hits_max..[[);
					update_chart("/stats/load.csv", "graph-load", ]]..info.load_max..[[);
					update_chart("/stats/mem.csv", "graph-mem", ]]..info.memory_max..[[);
					]]..(req:params().update and "setTimeout(draw_chart, 1000 * 60)" or "")..[[
				}
				]]
			},
			tags.style
			{
[[				main
				{
					margin: 0 auto;
					width: 800px;
					display:block;
				}
				div.graph
				{
					background-color: #eee;
					width: ]]..template.graphwidth..[[px;
					height: 100px;
					font-size: 0;
					vertical-align: top;
					overflow-y: hidden;
				}
				div.bar
				{
					height: 100%;
					width: ]]..template.barwidth..[[px;
					background-color: rgba(0,0,255, 0.1);
					border-top: 1px solid blue;
					display: inline-block;
					vertical-align: bottom;
				}
				
				@-webkit-keyframes flashred {
					0%   {background-color: rgba(255,0,0, 0.5);}
					100%  {background-color: rgba(255,0,0, 0.1);}
				}
				@keyframes flashred {
					0%   {background-color: rgba(255,0,0, 0.5);}
					100%  {background-color: rgba(255,0,0, 0.1);}
				}
				
				div.overflowbar
				{
					background-color: rgba(255,0,0, 0.1);
					border-top-color: red;
					
					-webkit-animation: flashred 1s infinite alternate;
					animation: flashred 1s infinite alternate;
				}
				td
				{
					padding-right: 15px;
					padding-left: 15px;
				}
				div.warning
				{
					background-color: #eee;
					font-family: monospace;
					overflow-x: auto;
					white-space: nowrap;
					height: auto;
					line-height:1em;
					max-height: 7em;
				}
				div.log
				{
					font-family: monospace;
				}
				footer
				{
					text-align: center;
					font-size: 0.75em;
					font-family: monospace;
					color: gray;
				}
				a
				{
					text-decoration: none;
					color: inherit;
				}]]
			}
		},
		tags.body
		{
			tags.main
			{
				unpack(contents)
			},
			tags.footer
			{
				"Instance: " .. script.instance()
			}
		}
	}.to_response(res)
end

function template.make_simple(req, res, contents)
	tags.html
	{
		tags.head
		{
			tags.title { "LuaFlare Statistics" },
			tags.style
			{
[[				main
				{
					margin: 0 auto;
					width: 800px;
					display:block;
				}
				td
				{
					padding-right: 15px;
					padding-left: 15px;
				}
				div.warning
				{
					background-color: #eee;
					font-family: monospace;
					overflow-x: auto;
					white-space: nowrap;
					height: auto;
					line-height:1em;
					max-height: 7em;
				}
				div.log
				{
					font-family: monospace;
				}
				footer
				{
					text-align: center;
					font-size: 0.75em;
					font-family: monospace;
					color: gray;
				}
				a
				{
					text-decoration: none;
					color: inherit;
				}]]
			}
		},
		tags.body
		{
			tags.main
			{
				unpack(contents)
			},
			tags.footer
			{
				"Instance: " .. script.instance()
			}
		}
	}.to_response(res)
end

function template.google_graph(title, id)
	return {
		tags.h2 { title },
		tags.div { id = "graph-" .. id }
	}	
end

function template.graph(title, units, data, argmax)
	local max = argmax
	for k,v in ipairs(data) do
		if not max or v.data > max then max = v.data end
	end

	local bars = {}
	for k,v in ipairs(data) do
		local class = "bar"
		if argmax ~= nil and v.data > argmax then
			class = class .. " overflowbar"
		end
		
		table.insert(bars, tags.div { 
			class = class,
			style = "height: " .. tostring(v.data/max*100) .. "%",
			title = tostring(v) .. units
		})
	end
	
	local gradient
	if argmax ~= nil and max > argmax then
		local perc = ((1 - argmax / max) * 100) .. "%"
		gradient = "background: linear-gradient(to bottom, rgba(0,0,0,0) "..perc..", #eee "..perc..");"
	end
	
	return tags.div
	{
		tags.h2 { string.format("%s: %s%s", title, tostring(data[#data].data), units) },
		tags.div { class = "graph", style = gradient }
		{
			tags.div { class = "bar", style = "height: 100%; width: 0px" },
			unpack(bars)
		}
	}
end

function template.section(name)
	local id = slug.generate(name)
	return tags.a { href = "#"..id, id = id }
	{
		tags.h1
		{
			name
		}
	}
end

function template.table(rows)
	local rows_elms = {}
	
	for k,row in pairs(rows) do
		local cols = {}
		for kk,col in pairs(row) do
			table.insert(cols, tags.td {col})
		end
		table.insert(rows_elms, tags.tr { unpack(cols) })
	end
	
	return tags.table
	{
		unpack(rows_elms)
	}
end

function template.mem_info(info)
	local elms = {}
	
	for k,proc in pairs(info) do
		table.insert(elms, tags.h3 { string.format("%s (%.2f MiB)", proc.name, proc.mem / 1024 / 1024) })
		local rows = {{ tags.b{"Memory"}, tags.b{"Name"} }}
		for k, mod in pairs(proc.modules) do
			table.insert(rows, {string.format("%d KiB", mod.mem / 1024), mod.name})
		end
		table.insert(elms, template.table(rows))
	end
	
	return elms
end

local ignore_packages = {
	_G = true, math = true, string = true, os = true, package = true, io = true, bit = true, bit32 = true, table = true,
	coroutine = true, debug = true
}

function template.package_info()
	local rows = {}
	
	for k,v in pairs(package.loaded) do
		local name = k
		local version
		
		if ignore_packages[name] then goto continue end
		
		if type(v) == "table" then
			version = v.VERSION or v._VERSION or v.version or v._version or tags.i{"Unknown"}
		else
			version = tags.i{"Unknown"}
		end
		
		local location = package.searchpath(name, package.path) or package.searchpath(name, package.cpath) or tags.i{"Unknown"}
		
		table.insert(rows, {name, version, location})
		::continue::
	end
	
	table.sort(rows, function(a,b)
		return a[1] < b[1]
	end)
	
	for n = 1, #rows do
		local name = rows[n][1]
		rows[n][1] = tags.a { href = "stats/module/" .. name } { name }
	end
	
	table.insert(rows, 1, { tags.b{"Name"}, tags.b{"Version"}, tags.b{"Location"} })
	return template.table(rows)
end

function template.scheduler_info()
	local rows = {
		{tags.b{"Name"}, tags.b{"Age"}, tags.b{"Tick Rate"}, tags.b{"CPU Time"}, tags.b{"CPU Time (/s)"}}
	}
	
	local totalcpu_time = 0
	local totalcpu_time_persec = 0
	
	for k, task in pairs(scheduler.tasks) do
		totalcpu_time         = totalcpu_time          + task.exectime
		totalcpu_time_persec  = totalcpu_time_persec   + task.exectime / (util.time() - task.born)
	end
	
	
	for k,task in pairs(scheduler.tasks) do
		local cputs = task.exectime / (util.time() - task.born)
		
		local tr = task.lasttickrate >= 1
			and (tostring(task.lasttickrate) .. "s")
			or  (tostring(1/task.lasttickrate) .. "/s")
		
		table.insert(rows, {
			task.name,
			tags.span {style="float:right;"} {string.format("%ds", util.time() - task.born)},
			tags.span {style="float:right;"} {tr},
			tags.span {style="float:right;"} {string.format("%.3fs (%.2f%%)", task.exectime, task.exectime / totalcpu_time * 100)},
			tags.span {style="float:right;"} {string.format("%.3fms (%.2f%%)", cputs * 1000, cputs / totalcpu_time_persec * 100)}
		})
	end
	
	return {
		template.table({
			{tags.b{"Idle Time"}, string.format("%fs", scheduler.idletime())}
		}),
		template.table(rows)
	}
end

function template.hook_info()
	local rows = {
		{ tags.b{"Hook"}, tags.b{"Priority"}, tags.b{"Name"}, tags.b{"Performance (calls = c)"} }
	}
	
	local t, c = 0, 0
	
	for k,v in pairs(hook.hooks) do
		t = t + v.time
		c = c + v.calls
	end
	
	for k,v in pairs(hook.hooks) do
		local msc = v.calls == 0 and 0 or ( v.time / v.calls * 1000.0 )
		
		table.insert(rows, { 
			tags.b{tostring(k)},
			"",
			"",
			string.format("%.2f%% %.2fs %dc %.1fms/call", v.time / t * 100.0, v.time, v.calls, msc)
		})
		
		for kk,vv in ipairs(v.callorder) do
			table.insert(rows, { "", tostring(vv.priority), tostring(vv.name) })
		end
	end
	
	return template.table(rows)
end

function template.warnings(warnings)
	local elms = {}
	
	if #warnings == 0 then
		return "None."
	end
	
	for k,warning in pairs(warnings) do
		table.insert(elms, tags.div
		{
			tags.h3 { os.date("%Y/%m/%d %H:%M:%S", warning.time) .. " \xd7 " .. warning.count },
			tags.div { class = "warning" }
			{
				warning.message
			}
		})
	end
	
	return tags.div
	{
		unpack(elms)
	}
end

function template.bootstrap_info()
	local elms = {}
	
	for k,log in ipairs(bootstrap.log_buffer) do
		table.insert(elms, tags.div
		{
			string.rep("\t", log.depth) .. log.text
		})
	end
	
	return tags.div { class = "log" }
	{
		unpack(elms)
	}
end

return template
