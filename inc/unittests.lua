local luaflare = require("luaflare")
local script = require("luaflare.util.script")
local escape = require("luaflare.util.escape")
local slug = require("luaflare.util.slug")

local FAILED = false
local SUB_FAIL = false

local lines = {}
for line in io.lines(luaflare.lib_path .. "/inc/unittests.lua") do
	table.insert(lines, line)
end

local function check(what)
	if not what then
		FAILED = true
		SUB_FAIL = true
		
		local file, line = debug.traceback():match("'check'\n[%s]*%[string \"([%a/%._-]+)\"%]:(%d+):")
		line = lines[tonumber(line)]:trim() -- FIXME: assume it's this file for now...
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
	check(math.round(5.4, 1) == 5)
	check(math.round(5.5, 1) == 6)
	check(math.round(5.6, 1) == 6)
	check(math.round(5.52, 0.1) == 5.5)
	check(math.round(5.58, 0.1) == 5.6)
	check(math.round(107, 10) == 110)
end

local function test_string()
	-- strings
	check(string.path("/test/file") == "/test/")
	check(string.path("/test/") == "/test/")
	check(string.path("/test") == "/")
	check(string.trim(" \n\t hello, world  \t\n  ") == "hello, world")
	check(string.trim(" . test . ") == ". test .")
	check(string.replace_last("test is test", "test", "simple") == "test is simple")
	check(string.starts_with("this is a test", "this "))
	check(not string.starts_with("this is a test", "is a"))
	check(string.ends_with("123456789", "789"))
	check(not string.ends_with("123456789", "678"))
	check(string.replace("this is a simple test", "is", "si") == "thsi si a simple test")
	check(string.replace("this is a simple test", "nope", "simple") == "this is a simple test")
end

local function test_escape()
	check(escape.html("<this> is a </test>") == "&lt;this&gt; is a &lt;/test&gt;")
	check(escape.html("< &lt; >") == "&lt; &amp;lt; &gt;")
	check(escape.html("<>&'\"") == "&lt;&gt;&amp;&apos;&quot;")
	check(escape.html("\t\n") == "&nbsp;&nbsp;&nbsp;&nbsp;<br />\n")
	
	check(escape.sql("this is ' a simple \"\" test") == "this is '' a simple \"\"\"\" test")
	
	check(escape.pattern("one (two) three % four.") == "one %(two%) three %% four%.")
	check(escape.pattern("(5 * 2) / 3 - 4 + 1") == "%(5 %* 2%) / 3 %- 4 %+ 1")
	check(escape.pattern("$5 ^ 2") == "%$5 %^ 2")
end

local function test_table()
	check(table.count({this=5, 15, 4, simple="test"}) == 4)
	check(table.count({1, 2, nil, 4}) == 3)
	check(table.count({}) == 0)
	
	check(table.is_empty({}))
	check(not table.is_empty({1, 2, 3}))
	check(not table.is_empty({a=1}))
	check(table.is_empty({nil}))
	
	check(table.has_key({a=5}, "a"))
	check(table.has_key({1, 2, 3}, 3))
	check(table.has_key({1}, 1))
	check(not table.has_key({1}, 2))
	check(not table.has_key({a=5}, "b"))
	
	check(table.has_value({1, 2, 3}, 2))
	check(not table.has_value({1, 2, 3}, 4))
	check(table.has_value({a=4, b=2}, 2))
	check(not table.has_value({a=4, b=2}, "a"))
	check(not table.has_value({a=4, b=2}, "4"))
	
	check(table.to_string({}) == "{}")
end

local function test_util()
	script.parse_arguments({"--123=abc", "--abc=123", "--test-val", "--test-val2=abc"}, nil, true)
	check(script.options["123"] == "abc")
	check(script.options["abc"] == "123")
	check(script.options["test-val"] == true)
	check(script.options["test-val2"] == "abc")
end

local function test_slug()
	check(slug.generate("Test") == "test")
	check(slug.generate("") == "")
	check(slug.generate("Hello, world!") == "hello-world")
	check(slug.generate("blah@def.com") == "blah-at-def-com")
	--check(slug.generate("áéíóúüñ") == "aeiouun") -- can't put unicode chars inline
end

local function test_recursive_require()
	local a = require("test.a")
	check(a.get() == 115)
end

function unit_test()
	test("circular require", test_recursive_require)
	test("table.* extensions", test_table)
	test("string.* extensions", test_string)
	test("math.* extensions", test_math)
	test("escape.*", test_escape)
	test("utility functions", test_util)
	test("slugs", test_slug)
	
	if FAILED then
		print("one or more unit test failed!")
		os.exit(1)	
	else
		print("all unit tests passed!")
		os.exit(0)
	end
end
