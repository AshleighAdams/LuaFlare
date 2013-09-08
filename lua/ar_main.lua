reqs.AddPattern("*", "/profile/(%d+)", function(request, response, id)
	response:append("Hello, you requested the profile id " .. id)
	local a = "hi"
	local b = "there"
	local c = a + b
end)