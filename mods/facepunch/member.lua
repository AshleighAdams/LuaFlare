-------------------------------------------------------------------------------
-- Member module and class definition
-- Facepunch Lua API
-- Authors: Andrew McWatters
--			Gran PC
--			Gregor Steiner
-------------------------------------------------------------------------------
local facepunch = require( "facepunch" )
local http = require( "facepunch.http" )
local session = require( "facepunch.session" )
local setmetatable = setmetatable
local string = string

module( "facepunch.member" )

-------------------------------------------------------------------------------
-- member.searchUser()
-- Purpose: Searches for users with the given string in their name, returns 0
--			then a table of the usernames if successful, otherwise 1 and nil
-- Input: name - partial or full string of user, must be at least 3 characters
--				 long to receive results
--		  session - option session object
--		  securityToken - security token for making the request
-- Output: error code, table of usernames
-------------------------------------------------------------------------------
function searchUser( name, securityToken )
	local postFields = "" ..
	-- Method
	"do=" .. "usersearch" ..
	-- PostID
	"&fragment=" .. name ..
	-- Securitytoken
	"&securitytoken=" .. ( securityToken or "guest" )

	local r, c = http.post( facepunch.rootURL .. "/" .. facepunch.ajaxPage, session.getActiveSession(), postFields )
	if ( c == 200 ) then
		local users = {}
		for id, user in string.gmatch( r, "<user userid=\"(.-)\">(.-)</user>" ) do
			users[ id ] = user
		end
		return 0, users
	else
		return 1, nil
	end
end

-------------------------------------------------------------------------------
-- member
-- Purpose: Class index
-------------------------------------------------------------------------------
local member = {}

-------------------------------------------------------------------------------
-- __metatable
-- Purpose: Class metatable
-------------------------------------------------------------------------------
__metatable = {
	__index = member,
	__type = "member"
}

-------------------------------------------------------------------------------
-- member.new()
-- Purpose: Creates a new member object
-- Output: member
-------------------------------------------------------------------------------
function new()
	local t = {
		userID = nil,
		username = nil,
		online = nil,
		usergroup = nil,
		usertitle = nil,
		avatar = nil,
		joinDate = nil,
		postCount = nil,
		links = nil
	}
	setmetatable( t, __metatable )
	return t
end

-------------------------------------------------------------------------------
-- member()
-- Purpose: Shortcut to member.new()
-- Output: member
-------------------------------------------------------------------------------
local metatable = {
	__call = function( _, ... )
		return new( ... )
	end
}
setmetatable( _M, metatable )

-------------------------------------------------------------------------------
-- member:__tostring()
-- Purpose: Returns a string representation of a member
-- Output: string
-------------------------------------------------------------------------------
function __metatable:__tostring()
	if not self.username then return "invalid member" end
	return "member: " .. self.username
end
