local tags = require("luaflare.tags")

return {
	make = function(self, title, heading, info, content, fgcol, bgcol)
		local template = tags.html
		{
			tags.head
			{
				tags.title { title },
				tags.style
				{[[
					@font-face {
						font-family: ProximaNovaCond;
						src: url("/luaflare/Proxima Nova-Regular.otf") format("opentype");
					}
					body {
						margin: 0;
						background: black; /* what to show after the mountains, should always be black */
						color: ]] .. (fgcol or "white") .. [[;
						font-family: "ProximaNovaCond",serif;
						position: relative;
					}
					h1 {
						font-size: 28pt;
					}
					div.mountains {
						width: 100%;
						height: 375px;
						background-image: url("/luaflare/mountain-silhouette.png");
						background-repeat: repeat-x;
						background-position: center bottom 0px;
					}
					div.atmosphere
					{
						width: 100%; /* rgba(150,50,0,1) */
						background: radial-gradient(2000px 800px at bottom, rgba(50,255,255,0.5), rgba(0,0,255,0.10) );
						z-index:-1;
					}
					div.space
					{
						background-image: url("/luaflare/space.png");
						z-index: -2;
					}
					div.background
					{
						width: 100%;
						height: 100%;
						position: absolute;
						background: ]] .. (bgcol or "transparent") .. [[;
						z-index:-1;
					}
		
					div.moon
					{
						width: 128px;
						height: 128px;
						top: 40px;
						left: 50%;
						position: relative;
						background-image: url("/luaflare/moon.png");
						background-size: 100% 100%;
						z-index:-1;
					}
					div.wrapper
					{
						width: 800px;
						margin: auto auto;
						padding-top: ]] .. (content == nil and "20vh" or "5vh") .. [[;
					}
				]]},
				tags.script
				{[[
					function rotate_moon()
					{
						var moon = document.getElementById('moon');
						var rotate = (new Date().getTime() / 50) % 360.0;
						var str = "rotate(" + rotate + "deg)";
						moon.style["-webkit-transform"] = str;
						moon.style["-moz-transform"] = str;
						moon.style["-ms-transform"] = str;
						moon.style["-o-transform"] = str;
						moon.style["transform"] = str;
					}
					setInterval(rotate_moon, 1/24*1000);
					document.addEventListener('DOMContentLoaded', rotate_moon, false);
				]]}
			},
			tags.body
			{
				tags.div { class = "space" }
				{
					tags.div { class = "atmosphere" }
					{
						tags.div { class = "wrapper" }
						{
							tags.center
							{
								tags.h1 { heading },
								info
							},
							tags.div { style = "display: table; margin: 0 auto;" }
							{
								content or {}
							}
						},
						tags.div { style = "overflow: show;" }
						{
							tags.div { class = "mountains" }
							{
								tags.div { class = "moon", id = "moon", onload = "rotate_moon();" }
							}
						}
					}
				}
			}
		}
		return template
	end
}

