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
				}
				div.bar
				{
					height: 100%;
					width: ]]..template.barwidth..[[px;
					background-color: blue;
					display: inline-block;
					vertical-align: bottom;
				}
				td
				{
					padding-right: 15px;
					padding-left: 15px;
				}]]
			}
		},
		tags.body
		{
			tags.main
			{
				unpack(contents)
			}
		}
	}.to_response(res)
end

function template.graph(title, units, data, max)
	if max == nil then
		for k,v in ipairs(data) do
			if not max or v > max then max = v end
		end
	end

	local bars = {}
	for k,v in ipairs(data) do
		table.insert(bars, tags.div { 
			class = "bar",
			style = "height: " .. tostring(v/max*100) .. "%",
			title = tostring(v) .. units
		})
	end
	
	return tags.div
	{
		tags.h2 { string.format("%s: %s%s", title, tostring(data[#data]), units) },
		tags.div { class = "graph" }
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
		{tags.b{"Name"}, tags.b{"Age"}, tags.b{"Tick Rate (/s)"}, tags.b{"CPU Time (s)"}, tags.b{"CPU Time (/s)"}}
	}
	
	local totalcpu_time = 0
	local totalcpu_time_persec = 0
	
	for k, task in pairs(scheduler.tasks) do
		totalcpu_time         = totalcpu_time          + task.exectime
		totalcpu_time_persec  = totalcpu_time_persec   + task.exectime / (util.time() - task.born)
	end
	
	
	for k,task in pairs(scheduler.tasks) do
		local cputs = task.exectime / (util.time() - task.born)
		
		table.insert(rows, {
			task.name,
			string.format("%d s", util.time() - task.born),
			tags.span {style="float:right;"} {string.format("%.3f", 1/task.lasttickrate)},
			tags.span {style="float:right;"} {string.format("%.3f (%.2f%%)", task.exectime, task.exectime / totalcpu_time * 100)},
			tags.span {style="float:right;"} {string.format("%.3f (%.2f%%)", cputs, cputs / totalcpu_time_persec * 100)}
		})
	end
	
	return template.table(rows)
end

return template
