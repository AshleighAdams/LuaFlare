-------------------------------------------------------------------------------
-- LuaSocket connector
-- Steam Web Lua API
-- Authors: Andrew McWatters
--			Gran PC
--			Matt Stevens
--			Gregor Steiner
-------------------------------------------------------------------------------
local http = require( "socket.http" )
require( "ssl.https" )
local https = ssl.https
local ltn12 = require( "ltn12" )
local string = string
local table = table

function steamwebapi.http.get( URL )
	local t = {}
	local r, c, h = http.request({
		url = URL,
		sink = ltn12.sink.table( t )
	})
	r = table.concat( t, "" )
	return r, c
end

function steamwebapi.http.post( URL, postData )
	local t = {}
	postData = postData or ""
	local headers = {}
	headers[ "Content-Type" ] = "application/x-www-form-urlencoded"
	headers[ "Content-Length" ] = string.len( postData )
	local r, c, h = http.request( {
		url = URL,
		source = ltn12.source.string( postData ),
		sink = ltn12.sink.table( t ),
		method = "POST",
		headers = headers,
	}, postData )
	r = table.concat( t, "" )
	return r, c
end

function steamwebapi.https.get( URL )
	local t = {}
	local r, c, h = https.request({
		url = URL,
		sink = ltn12.sink.table( t )
	})
	r = table.concat( t, "" )
	return r, c
end

function steamwebapi.https.post( URL, postData )
	local t = {}
	postData = postData or ""
	local headers = {}
	headers[ "Content-Type" ] = "application/x-www-form-urlencoded"
	headers[ "Content-Length" ] = string.len( postData )
	headers[ "User-Agent" ] = steamwebapi.getUserAgent()
	local r, c, h = https.request( {
		url = URL,
		source = ltn12.source.string( postData ),
		sink = ltn12.sink.table( t ),
		method = "POST",
		headers = headers,
	}, postData )
	r = table.concat( t, "" )
	return r, c
end
