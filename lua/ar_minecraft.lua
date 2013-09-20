reqs.AddPattern("*", "/minecraft/report", function(request, response, id)
	
	for k,v in pairs(request.parsed_url.params) do
		response:append(k .. " is " .. v .. "<br/>")
	end
	
end)