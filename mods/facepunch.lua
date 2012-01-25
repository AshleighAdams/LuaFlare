-------------------------------------------------------------------------------
-- Scripted interfacing for Facepunch
-- Facepunch Lua API
-- Authors: Andrew McWatters
--			Gran PC
--			Gregor Steiner
-------------------------------------------------------------------------------
local require = require

module( "facepunch" )

http	= require( "facepunch.http" )
member	= require( "facepunch.member" )
post	= require( "facepunch.post" )
session	= require( "facepunch.session" )
thread	= require( "facepunch.thread" )
url		= require( "facepunch.url" )

baseURL			= "http://www.facepunch.com/"
rootURL			= "http://www.facepunch.com"
ajaxPage		= "ajax.php"
loginPage		= "login.php"
newReplyPage	= "newreply.php"

-------------------------------------------------------------------------------
-- facepunch.isUp()
-- Purpose: Returns true if not downpunch
-- Output: boolean
-------------------------------------------------------------------------------
function isUp()
	local r, c = http.get( rootURL )
	return c == 200
end
