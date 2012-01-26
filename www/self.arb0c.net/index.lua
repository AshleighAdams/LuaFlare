Hello, <?lua write(GET.name or "Anonymous") ?>.  How are you doing?
<br/>
<br/>
Would you like to see my table?

<?lua
include("inc/testinc.lua")

local TestTable = {
	TestNumber = 123,
	TestString = "Hello, world!",
	TestFunc = function() end,
	TestTable2 = {
		Does_this_work = true,
		Well = "it sure does!"
	}
}

PrintTable(TestTable)

?>


Well, this is a test.
<br/>
[[ This string should perform ]] fine.
<br/>
<?lua


-- None of these ?>
--[[
 ?> will <? lua break it\]
]]

local x = [[ just testing ]]
local y = "Escapes \" also work"
local z = [[And escaping \]in here won't break anything]]
write(z)
?>
