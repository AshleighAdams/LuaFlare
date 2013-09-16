local FAILED = false
local SUB_FAIL = false

local lines = {}
for line in io.lines("inc/unittests.lua") do
	table.insert(lines, line)
end

local function check(what)
	if not what then
		FAILED = true
		SUB_FAIL = true
		
		local file, line = debug.traceback():match("'check'\n[%s]*([%a/%._-]+):(%d+):")
		
		line = lines[tonumber(line)]:Trim() -- FIXME: assume it's this file for now...
		line = line:match("check%s*(%b())")
		print("failed: " .. line .. " != true")
	end
end

local function test(msg, func)
	local toprint = msg .. "... "
	
	SUB_FAIL = false
	local suc, ret = pcall(func)
	if not suc then
		FAILED = true
		toprint = toprint .. "error: " .. (lines[tonumber(ret:match("inc/unittests%.lua:(%d+):"))] or ret)
	elseif SUB_FAIL then
		FAILED = true
		toprint = toprint .. "fail"
	else
		toprint = toprint .. "pass"
	end
	
	print(toprint)
end

local function test_math()
	-- maths
	check(math.Round(5.4, 1) == 5)
	check(math.Round(5.5, 1) == 6)
	check(math.Round(5.6, 1) == 6)
	check(math.Round(5.52, 0.1) == 5.5)
	check(math.Round(5.58, 0.1) == 5.6)
end

local function test_string()
	-- strings
	check(string.Path("/test/file") == "/test/")
	check(string.Path("/test/") == "/test/")
	check(string.Path("/test") == "/")
	check(string.Trim(" \n\t hello, world  \t\n  ") == "hello, world")
	check(string.Trim(" . test . ") == ". test .")
	check(string.ReplaceLast("test is test", "test", "simple") == "test is simple")
	check(string.StartsWith("this is a test", "this "))
	check(not string.StartsWith("this is a test", "is a"))
	check(string.EndsWith("123456789", "789"))
	check(not string.EndsWith("123456789", "678"))
	check(string.Replace("this is a simple test", "is", "si") == "thsi si a simple test")
	check(string.Replace("this is a simple test", "nope", "simple") == "this is a simple test")
end

local function test_escape()
	check(escape.html("<this> is a </test>") == "&lt;this&gt; is a &lt;/test&gt;")
	check(escape.html("< &lt; >") == "&lt; &amp;lt; &gt;")
	check(escape.html("<>&'\"") == "&lt;&gt;&amp;&apos;&quot;")
	check(escape.html("\t\n") == "&nbsp;&nbsp;&nbsp;&nbsp;<br />\n")
	
	check(escape.sql("this is ' a simple \"\" test") == "this is \\' a simple \\\"\\\" test")
	
	check(escape.pattern("one (two) three % four.") == "one %(two%) three %% four%.")
	check(escape.pattern("(5 * 2) / 3 - 4 + 1") == "%(5 %* 2%) / 3 %- 4 %+ 1")
end

local function test_table()
	check(table.Count({this=5, 15, 4, simple="test"}) == 4)
	check(table.Count({1, 2, nil, 4}) == 3)
	check(table.Count({}) == 0)
	
	check(table.IsEmpty({}))
	check(not table.IsEmpty({1, 2, 3}))
	check(not table.IsEmpty({a=1}))
	check(table.IsEmpty({nil}))
	
	check(table.HasKey({a=5}, "a"))
	check(table.HasKey({1, 2, 3}, 3))
	check(table.HasKey({1}, 1))
	check(not table.HasKey({1}, 2))
	check(not table.HasKey({a=5}, "b"))
	
	check(table.HasValue({1, 2, 3}, 2))
	check(not table.HasValue({1, 2, 3}, 4))
	check(table.HasValue({a=4, b=2}, 2))
	check(not table.HasValue({a=4, b=2}, "a"))
	check(not table.HasValue({a=4, b=2}, "4"))
	
	check(table.ToString({}) == "{}")
end

function unit_test()
	test("table.* extensions", test_table)
	test("string.* extensions", test_string)
	test("math.* extensions", test_math)
	test("escape.*", test_escape)
	
	if FAILED then
		print("unit test failed!")
		os.exit(1)	
	else
		print("all unit tests passed!")
		os.exit(0)
	end
end
