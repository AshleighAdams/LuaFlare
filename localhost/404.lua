-- Eh, something went wrong

con.write([[
<!DOCTYPE html>
<html>
	<head>
		<title>404</title>
	</head>
	<body>
		<style>
			body{
				background-color: #f1f1f1;
			       
				padding: 50px;
			}
		</style>
	       
		<div style="margin: 0px auto; width: 128px;">
			<span style="font-size: 80px; font-style: italic; color: #3e3e3e; font-family: 'Trebuchet MS'; text-shadow: #ebebeb 0px 1px 0px;">404</span>
		</div>
	       
		<div style="padding: 15px; 0px; background-color: #ffffff; width: 128px; margin: 0px auto; box-shadow: rgba(0, 0, 0, 0.15) 0px 0px 25px;">
			<span style="font-size: 18px; font-style: italic; color: #3e3e3e; font-family: 'Trebuchet MS';">Page not found</span>
		</div>
	</body>
</html>
<!-- 404 page created by ddrl -->
]])
con.errcode = 404
