
local function renamed_func(tbl, tblname, name, old)
	local func = tbl[name] or error("could not find func " .. name, 2)
	local strn = ("%s.%s"):format(tblname, name)
	local stro = ("%s.%s"):format(tblname, old)
	local msg = ("%s renamed to %s"):format(stro, strn)
	tbl[old] = function(...)
		warn(msg .. "\n" .. debug.traceback())
		return func(...)
	end
end

renamed_func(table, "table", "count", "Count")
renamed_func(table, "table", "remove_value", "RemoveValue")
renamed_func(table, "table", "is_empty", "IsEmpty")
renamed_func(table, "table", "has_key", "HasKey")
renamed_func(table, "table", "has_value", "HasValue")
renamed_func(table, "table", "to_string", "ToString")

renamed_func(string, "string", "starts_with", "StartsWith")
renamed_func(string, "string", "ends_with", "EndsWith")
renamed_func(string, "string", "replace", "Replace")
renamed_func(string, "string", "path", "Path")
renamed_func(string, "string", "replace_last", "ReplaceLast")
renamed_func(string, "string", "trim", "Trim")
renamed_func(string, "string", "split", "Split")

renamed_func(math, "math", "round", "Round")
renamed_func(math, "math", "secure_random", "SecureRandom")






























