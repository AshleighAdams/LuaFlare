-- Eh, something went wrong

con.write([[
<html>
	<head>
		<title>luaserver</title>
		<style>
			
		</style>
	</head>
	<body>
		<div class="main">
			<div class="title">
				404 - File Not Found
			</div>
			<div class="explain">
				The file you are searching for can not be found
			</div>
			
			<div class="foot">
				luaserver
			</div>
		</div>
	</body>
<html>]])
con.errcode = 404
