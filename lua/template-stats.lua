local tags = require("luaserver.tags")
local scheduler = require("luaserver.scheduler")
local script = require("luaserver.util.script")

local template = {}
template.barwidth = 1;
template.graphwidth = 800;
template.bars = template.graphwidth / template.barwidth

function template.make(req, res, contents)
	tags.html
	{
		tags.head
		{
			tags.title { "LuaServer Statistics" },
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
				footer
				{
					text-align: center;
					font-size: 0.75em;
					font-family: monospace;
					color: gray;
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

function template.graph(title, units, data, argmax)
	local max = argmax
	for k,v in ipairs(data) do
		if not max or v > max then max = v end
	end

	local bars = {}
	for k,v in ipairs(data) do
		local class = "bar"
		if argmax ~= nil and v > argmax then
			class = class .. " overflowbar"
		end
		
		table.insert(bars, tags.div { 
			class = class,
			style = "height: " .. tostring(v/max*100) .. "%",
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
		tags.h2 { string.format("%s: %s%s", title, tostring(data[#data]), units) },
		tags.div { class = "graph", style = gradient }
		{
			tags.div { class = "bar", style = "height: 100%; width: 0px" },
			unpack(bars)
		}
	}
end

function template.section(name)
	return tags.h1 { name }
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

return template
