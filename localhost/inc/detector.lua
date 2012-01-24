
function Site()
	local ret = {}
	
	ret.write_header = function(title)
		con.writef([[
<html>
	<head>
		<title>%s</title>
	</head>
	<body>
		]], EscapeHTML(title))
	end
	
	ret.write_footer = function()
		con.writef([[
	</body>
</html>
		]])
	end
	
	return ret
end
