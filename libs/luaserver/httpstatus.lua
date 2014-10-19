local httpstatus = {}

httpstatus.know_statuses = {
	-- 1XX
	[100] = "Continue",
	[101] = "Switching Protocols",
	[102] = "Processing",
	
	-- 2XX
	[200] = "OK",
	[201] = "Created",
	[202] = "Accepted",
	[203] = "Non-Authoritative Information",
	[204] = "No Content",
	[205] = "Reset Content",
	[206] = "Partial Content",
	[207] = "Multi-Status",
	[208] = "Already Reported",
	
	[226] = "IM Used",
	
	-- 3XX
	[300] = "Multiple Choices",
	[301] = "Moved Permanently",
	[302] = "Found",
	[303] = "See Other",
	[304] = "Not Modified",
	[305] = "Use Proxy",
	
	[307] = "Temporary Redirect",
	[308] = "Permanent Redirect",
	
	-- 4XX
	[400] = "Bad Request",
	[401] = "Unauthorized",
	[402] = "Payment Required",
	[403] = "Forbidden",
	[404] = "Not Found",
	[405] = "Method Not Allowed",
	[406] = "Not Acceptable",
	[407] = "Proxy Authentication Required",
	[408] = "Request Timeout",
	[409] = "Conflict",
	[410] = "Gone",
	[411] = "Length Required",
	[412] = "Precondition Failed",
	[413] = "Request Entity Too Large",
	[414] = "Request-URI Too Long",
	[415] = "Unsupported Media Type",
	[416] = "Requested Range Not Satisfiable",
	[417] = "Expectation Failed",
	[418] = "I'm a teapot",
	
	[420] = "Enhance Your Calm",
	
	[422] = "Unprocessable Entity",
	
	[423] = "Locked",
	[424] = "Failed Dependency",
	
	[426] = "Upgrade Required",
	
	[428] = "Precondition Required",
	[429] = "Too Many Requests",
	
	[431] = "Request Header Fields Too Large",
	
	[451] = "Unavailable For Legal Reasons",
	
	-- 5XX
	[500] = "Internal Server Error",
	[501] = "Not Implemented",
	[502] = "Bad Gateway",
	[503] = "Service Unavailable",
	[504] = "Gateway Timeout",
	[505] = "HTTP Version Not Supported",
	[506] = "Variant Also Negotiates",
	[507] = "Insufficient Storage",
	[508] = "Loop Detected",
	
	[510] = "Not Extended",
	[511] = "Network Authentication Required",
}

function httpstatus.tostring(number) expects "number"
	return httpstatus.know_statuses[number]
end

httpstatus.reverse_cache = {}
for status, message in pairs(httpstatus.know_statuses) do
	message = message:lower()
	httpstatus.reverse_cache[message:lower():gsub("%s", "")] = status
end

-- "404", "404 not found", "404 notfound", "notfound", "not found", "Not Found", ....
-- should all return the same
-- "404 Internal Server Error" should yield 404
function httpstatus.fromstring(str) expects "string"
	local code, message = str:match("(%d*)%s*(.*)")
	
	-- the code takes priority
	if code ~= "" then
		return tonumber(code)
	elseif message ~= nil then
		message = message:lower():gsub("%s", "") -- so NotFound, not found, notfound Not Found are same
		return httpstatus.reverse_cache[message]
	else
		return nil
	end
end

return httpstatus
