<form action="compile.lua" method="GET">
	<textarea name="lua" wrap="off" rows=10 cols=100>
<?lua write(GET.lua or "") ?>
	</textarea>
	<input type="submit" />
</form>

<br/>

<?lua

if GET.lua then
	local lua, err = ParseLuaString(GET.lua)
	
	if not lua then
		write("string:EOF: " .. err)
	else
		write(lua)
	end
end

?>
