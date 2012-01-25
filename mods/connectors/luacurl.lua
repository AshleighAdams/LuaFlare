-------------------------------------------------------------------------------
-- LuaCURL connector
-- Facepunch Lua API
-- Authors: Andrew McWatters
--			Gran PC
--			Gregor Steiner
-------------------------------------------------------------------------------
require( "luacurl" )

local curl = curl
local string = string
local table = table
local tonumber = tonumber

local function curlWrite( bufferTable )
	return function( stream, buffer )
		table.insert( bufferTable, buffer )
		return string.len( buffer )
	end
end

function facepunch.http.get( URL, session )
	local ht = {}
	local t = {}
	local curlObj = curl.new()
	
	curlObj:setopt( curl.OPT_HEADER, true )
	curlObj:setopt( curl.OPT_HEADERFUNCTION, curlWrite( ht ) )
	curlObj:setopt( curl.OPT_WRITEFUNCTION, curlWrite( t ) )
	curlObj:setopt( curl.OPT_URL, URL )
	if ( session and session.cookie ) then
		curlObj:setopt( curl.OPT_COOKIE, session.cookie )
	end
	
	curlObj:perform()
	curlObj:close()
	
	local hr = table.concat( ht, "" )
	local r = table.concat( t, "" )
	local h, c, m = string.match( r, "(.-) (.-) (.-)\n" )
	t = {}
	for cookie in string.gmatch( hr, "Set%-Cookie: (.-);" ) do
		table.insert( t, cookie )
	end
	local cookie = table.concat( t, "; " )
	return r, tonumber( c ), cookie
end

function facepunch.http.post( URL, session, postData )
	local ht = {}
	local t = {}
	local curlObj = curl.new()
	
	curlObj:setopt( curl.OPT_HEADER, true )
	curlObj:setopt( curl.OPT_HEADERFUNCTION, curlWrite( ht ) )
	curlObj:setopt( curl.OPT_WRITEFUNCTION, curlWrite( t ) )
	curlObj:setopt( curl.OPT_URL, URL )
	curlObj:setopt( curl.OPT_POSTFIELDS, postData )
	if ( session and session.cookie ) then
		curlObj:setopt( curl.OPT_COOKIE, session.cookie )
	end
	
	curlObj:perform()
	curlObj:close()
	
	local hr = table.concat( ht, "" )
	local r = table.concat( t, "" )
	local h, c, m = string.match( r, "(.-) (.-) (.-)\n" )
	t = {}
	for cookie in string.gmatch( hr, "Set%-Cookie: (.-);" ) do
		table.insert( t, cookie )
	end
	local cookie = table.concat( t, "; " )
	return r, tonumber( c ), cookie
end
