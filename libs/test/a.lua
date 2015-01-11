local a = {}

local b = require("test.b")

function a.b_needs_this()
	return 10
end

function a.get()
	return 100 + b.a_needs_this()
end

return a
