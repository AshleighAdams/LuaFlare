local canon = {}

local hook = require("luaflare.hook")

canon.canonical_headers_str = [[
Accept
Accept-Charset
Accept-Encoding
Accept-Language
Accept-Datetime
Authorization
Cache-Control
Connection
Cookie
Content-Length
Content-MD5
Content-Type
Date
Expect
From
Host
Permanent
If-Match
If-Modified-Since
If-None-Match
If-Range
If-Unmodified-Since
Max-Forwards
Origin
Pragma
Proxy-Authorization
Range
Referer
TE
Upgrade
User-Agent
Via
Warning
X-Requested-With
DNT
X-Forwarded-For
X-Forwarded-Proto
Front-End-Https
X-ATT-DeviceId
X-Wap-Profile
Proxy-Connection
Access-Control-Allow-Origin
Accept-Ranges
Age
Allow
Cache-Control
Connection
Content-Encoding
Content-Language
Content-Length
Content-Location
Content-MD5
Content-Disposition
Content-Range
Content-Type
Date
ETag
Expires
Last-Modified
Link
Location
P3P
Pragma
Proxy-Authenticate
Refresh
Retry-After
Permanent
Server
Set-Cookie
Status
Strict-Transport-Security
Trailer
Transfer-Encoding
Vary
Via
Warning
WWW-Authenticate
X-Frame-Options
X-XSS-Protection
Content-Security-Policy
X-Content-Security-Policy
X-WebKit-CSP
X-Content-Type-Options
X-Powered-By
X-UA-Compatible
X-Sendfile
X-Accel-Redirect
]]

local function load_canon_headers()
	local split = canon.canonical_headers_str:split("\n")
	canon.canonical_headers = {}

	for k, v in pairs(split) do
		local hdr = v:trim()
		if hdr ~= "" then
			canon.canonical_headers[hdr:lower()] = hdr
		end
	end
end

hook.add("Loaded", "load canonical headers", load_canon_headers)

function canon.get_header(string header)
	local lwr = header:lower()
	return canon.canonical_headers[lwr] or header
end

return canon
