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
