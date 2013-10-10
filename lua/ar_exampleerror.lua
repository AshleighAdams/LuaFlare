
local function exampleerror(req, res, str)
	local testbl = {argument = str, time = util.time()}
	local result = testbl .. _G
	req:append("done")
end

reqs.AddPattern("*", "/examplerrror/(*)", exampleerror)