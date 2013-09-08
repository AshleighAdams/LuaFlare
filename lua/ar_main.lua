reqs.AddPattern("*", "/profile/(%d+)", function(request, response, id)
	id = tonumber(id)
	
	-- error is on purpose
	response:apend("Hello, you requested the profile id " .. id .. tostring(request))
end)