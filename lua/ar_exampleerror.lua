
local function exampleerror(req, res, str)
	local result = str .. _G
	req:append("done")
end

reqs.AddPattern("*", "/examplerrror/(*)", exampleerror)