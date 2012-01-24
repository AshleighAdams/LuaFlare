-- Eh, something went wrong

con.writenf([[
<html>
	<head>
		<title>luaserver</title>
		<style>
			div.main{
				margin-left:auto;
				margin-right:auto;
				margin-top:100px;
				margin-bottom:auto;
				
				width: 800px;
			}
			div.title{
				text-align: center;
				color: #a1a1a1;
				font-size: 200%;
				padding: 10px;
				float: left;
				#border-right: 1px solid #a1a1a1;
				height: 50%;
			}
			div.explain{
				padding-top: 100px;
			}
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
			<br/>
			
		</div>
	</body>
<html>
<!-- luaserver -->
]])
con.errcode = 404
