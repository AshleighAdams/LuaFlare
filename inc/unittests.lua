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

local function test_util()
	SUB_FAIL = false
	
	-- maths
	check(math.Round(5.4, 1) == 5)
	check(math.Round(5.5, 1) == 6)
	check(math.Round(5.6, 1) == 6)
	check(math.Round(5.52, 0.1) == 5.5)
	check(math.Round(5.58, 0.1) == 5.6)
	
	-- strings
	check(string.Path("/test/file") == "/test/")
	check(string.Path("/test/") == "/test/")
	--check(string.Path("/test") == "/")
	check(string.Trim(" \n\t hello, world  \t\n  ") == "hello, world")
	check(string.ReplaceLast("test is test", "test", "simple") == "test is simple")
	
	return not SUB_FAIL
end

local function test(msg, func)
	local toprint = msg .. "... "
	
	local suc, ret = pcall(func)
	if not suc then
		FAILED = false
		toprint = toprint .. "error: " .. lines[tonumber(ret:match("inc/unittests%.lua:(%d+):"))] or ret
	elseif not ret then
		toprint = toprint .. "fail"
	else
		toprint = toprint .. "pass"
	end
	
	print(toprint)
end

function unit_test()
	test("test util.* functions", test_util)
	
	return FAILED and 1 or 0
end
