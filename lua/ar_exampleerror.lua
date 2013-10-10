
local function exampleerror(req, res, str)
	local tbl = _G
	local result = str .. tbl
	req:append("done")
end

reqs.AddPattern("*", "/examplerrror/(*)", exampleerror)