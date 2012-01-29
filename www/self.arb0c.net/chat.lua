
<?lua
	if GET.name then
		SESSION.name = EscapeHTML(GET.name)
		write(false, [[<script>document.location = "/chat.lua";</script>]])
		
		Lock(function()
			local tbl = table.load("chatshit.txt")
			local msg = {
				when = GetCurrentTime(),
				msg = SESSION.name .. " joined chat."
			}
			table.insert(tbl, msg)
			table.save("chatshit.txt", tbl)
		end)
		
		return
	elseif SESSION.name then
		Lock(function()
			local tbl = table.load("chatshit.txt")
			local msg = {
				when = GetCurrentTime(),
				msg = SESSION.name .. " refreshed chat."
			}
			table.insert(tbl, msg)
			table.save("chatshit.txt", tbl)
		end)
	end
?>
<html>
	<head>
		<script src="http://code.jquery.com/jquery-1.3.2.js"></script>
		<script src="/chat.js"></script>
		<title>luaserver Chat Test</title>
	</head>
	<body>
		<?lua
			if not SESSION.name then
				?>
					<form action="/chat.lua" method="GET">
						Enter a name: <input type="Text" name="name"/>
						<input type="submit"/>
					</form>
				<?lua
				return
			end
		?>
<textarea id="chatbox" rows=30 cols=120></textarea>
		<br/>
		<form id="chatform" onSubmit="return SendChat();">
			<input type="text" id="tosay" size="110"/>
			<input type="submit"/>
		</form>
	</body>
</html>
