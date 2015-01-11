local b = {}

local a = require("test.a")

function b.a_needs_this()
	return 5 + a.b_needs_this()
end

return b
