
local sqlbuilder = {}
sqlbuilder._VERSION = "sql-builder 0.1"

sqlbuilder.select = function(what, tbl)
	local ret = {}
	local options = ""
	local prefix = " WHERE"
	local limit

	local query = string.format("SELECT %s FROM `%s`", escape.sql(what), escape.sql(tbl))

	local function generate_op(op)
		local op = op
		return function(key, value)
			if type(value) == "string" then
			value = string.format([["%s"]], escape.sql(value))
			else
				value = escape.sql(tostring(value))
			end
			key = escape.sql(tostring(key))

			query = string.format("%s%s %s %s %s", query, prefix, key, op, value)
			prefix = ""
		end
	end

	ret.more_than = generate_op(">")
	ret.less_than = generate_op("<")
	ret.equals = generate_op("=")
	ret.less_than_or_equal = generate_op("<=")
	ret.more_than_or_equal = generate_op(">=")

	ret.limit = function(number)
		limit = number
	end

	ret.get = function()
		if limit ~= nil then query = string.format("%s LIMIT %d", query, limit) end
		return query
	end

	return ret
end

return sqlbuilder

