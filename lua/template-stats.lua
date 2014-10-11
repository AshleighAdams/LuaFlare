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

return template
