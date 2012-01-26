
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
