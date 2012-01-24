-- Welcome to the lua test page!

con.write([[
<html>
	<head>
		<title>Welcome to the lua test page!</title>
	</head>
	<body>
		<table border="0">
			<tr>
			<td>Param&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</td>
			<td>Value</td>
		</tr>
]])
for k,v in pairs(con.GET) do
	con.write([[
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

