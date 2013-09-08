reqs.AddPattern("*", "/profile/(%d+)", function(request, response, id)
	id = tonumber(id)
	response:append("Hello, you requested the profile id " .. id)
	local a = "hi"
	local b = "there"
	local c = id + a .. b
end)