
build_template = tags.html
{
	tags.head
	{
		tags.title { "Build Server" },
		tags.meta {["http-equiv"] = "Content-Type", content="text/html; charset=UTF-8"},
		tags.link {type="text/css", rel="stylesheet", href="/build/style.css"}
	},
	tags.body
	{
		tags.div {class = "wrapper"}
		{
			tags.div {class = "tpbr"}{ tags.img {src = "/build/imgs/header.png" } },
			tags.div {class = "lineup"}
			{
				tags.span {class = "lineupl"},
				tags.span {class = "lineupr"},
				tags.span {class = "lineup"}
			},
			tags.div {class = "side"}
			{
				tags.h1 {class = "side" } { "Menu" },
				tags.div {class = "linedownweak", style="clear: both; overflow: visible;"}
				{
					tags.span {class = "linedownlweak"},
					tags.span {class = "linedownweak"}
				},
				tags.ul {class = "sb"}
				{
					tags.li {class="sbcurrent"}{ tags.a {href="#"}{"Home"} },
					tags.li {class="sb"}{ tags.a {href="#"}{"About"} },
					--tags.li {class="sbl"}{ "Builds" },
					
					
					tags.h1 {class = "side" } { "Builds" },
					
					tags.div { style="clear: both; overflow: visible;height: 7px"}
					{
						tags.div {class = "lineup"}
						{
							tags.span {class = "lineupweak", style = "margin-right: 0px;"}
						},
						tags.span {class = "lineuplweak", style = "position: relative;"}
					},
					
				--	tags.div {class = "linedownweak", style="clear: both; overflow: visible;"}
				--	{
				--		
				--		tags.span {class = "linedownlweak"},
				--		tags.span {class = "linedownweak"}
				--	},
					
					
					tags.li {class="sb"}{ tags.a {href="#"}{"LuaPP"} },
					tags.li {class="sb"}{ tags.a {href="#"}{"LuaServer"} }
				}
			},
			tags.div {class = "main"}
			{
				tags.h2 { "Main Title" },
				tags.p
				{
					"The main content of the page goes right here..."
				}
			},
			tags.div {class = "linedown", style = "clear: both; overflow: visible;"}
			{
				tags.span {class = "linedownl"},
				tags.span {class = "linedownr"},
				tags.span {class = "linedown"}
			},
			tags.div {class = "foot"}
			{
				"Copyright &copy; " .. os.date("*t").year .. " Blah.  All rights reserved."
			}
		}
	}
}