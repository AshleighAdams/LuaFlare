<?lua
	if GET.name then
		SESSION.name = EscapeHTML(GET.name)
?>
<script>document.location = "/";</script>
<?lua
		return
	end
?>
<html>
	<head>
		<title>Hurp Derp (Don't break your F5 key)</title>
	</head>
	<body>
<?lua
if not SESSION.name then
?>
				<form action="/">
					Enter your name: <input type="text" name="name"/>
					<input type="submit"/>
				</form>
<?lua
else
	SESSION.TimesSeen = (SESSION.TimesSeen or 1) + 1
	writef(false, "Hello, %s; I last seen you %s seconds ago, I have also seen you %s times.<br/>\n", SESSION.name, os.time() - (SESSION.LastSeen or os.time()), SESSION.TimesSeen)
end
?>
		<center>
			<br/>This page took
			<?lua
				local mt = GetMicroTime()
				local s = mt / 1000000
				writef("%s micro seconds (%s seconds)", tostring(mt), tostring(s))
			?> to create and execute. <?lua if PRECACHED then write("(precached)") end ?>
		</center>
	</body>
<html>
