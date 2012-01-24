-- Welcome to the lua test page!

con.write([[
<html>
	<head>
		<title>Welcome to the lua test page!</title>
	</head>
	<body>
		<table border="0">
			<tr>
				<td>Headers</td>
			</tr>
]])

for k,v in pairs(con.HEADER) do
	con.writef([[
			<tr>
				<td>%s</td>
				<td>%s</td>
			</tr>
	]], k, v)
end

con.write([[
			<tr>
				<td>GET</td>
			</tr>]])

for k,v in pairs(con.GET) do
	con.writef([[
			<tr>
				<td>%s</td>
				<td>%s</td>
			</tr>
	]], k, v)
end

con.write([[
			<tr>
				<td>Cookies</td>
			</tr>]])

for k,v in pairs(con.COOKIE) do
	con.writef([[
			<tr>
				<td>%s</td>
				<td>%s</td>
			</tr>
	]], k, v)
end



con.write([[
		</table>
	</body>
<html>]])

con.set_cookies["remove"] = "urdad; path=/; expires=Thu, Jan 01 1970 00:00:00 UTC; "
