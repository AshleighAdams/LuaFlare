<html>
	<head>
		<title>Lua compiling test page</title>
	</head>
	</body>
<?lua
local deflua = [[Well, this is a test.
<br/>
]] .. "[[" .. [[This string should perform]] .. "]]" .. [[fine.
<br/>
<?lua


-- None of these ?>
--]] .. "[[" .. [[
 ?> will <?lua break it\]
]] .. "]]" .. [[

local x = ]] .. "[[" .. [[ just testing ]] .. "]]" .. [[

local y = "Escapes \" also work"
local z = ]] .. "[[" .. [[And escaping \]in here won't break anything]] .. "]]" .. [[

write(z)

?>]]
?>

		<form action="compile.lua" method="GET">
			<textarea name="lua" wrap="off" rows=20 cols=100>

<?lua write(GET.lua or deflua) ?>
			
			</textarea>
			<br/>
			<input type="submit" />
		</form>

		<br/>

		<pre>
		
		<?lua

		if GET.lua then
			local lua, err = ParseLuaString(GET.lua)
			
			if not lua then
				write("string:EOF: " .. err)
			else
				lua = EscapeHTML(lua)
				write(false, lua)
			end
		end

		?>
		</pre>
		<center>
			
			<?lua
				SESSION.TimesSeen = (SESSION.TimesSeen or 0) + 1
				
				writef(false, "I have seen you %s times<br/>", tostring(SESSION.TimesSeen))
				
				if GET.loops then
					local l = tonumber(GET.loops)
					if l > 10000000 then
						write("loop capped to 10000000")
						l = 10000000
					end
					for i = 0, l do end
				else
					?> <br/>Add the param "loops" to create an artificial loop <?lua
				end
			?>
			<br/>This page took
			<?lua
				local mt = GetMicroTime()
				local s = mt / 1000000
				writef("%s micro seconds (%s seconds)", tostring(mt), tostring(s))
			?> to create and execute.
		</center>
	</body>
<html>
