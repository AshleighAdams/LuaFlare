-------------------------------------------------------------------------------
-- Session module and class definition
-- Facepunch Lua API
-- Authors: Andrew McWatters
--			Gran PC
--			Gregor Steiner
-------------------------------------------------------------------------------
local facepunch = require( "facepunch" )
local http = require( "facepunch.http" )
local setmetatable = setmetatable
local string = string
local print = print

module( "facepunch.session" )

-------------------------------------------------------------------------------
-- logoutHashPattern
-- Purpose: Pattern for filling the logout hash URL parameter when logging out
-------------------------------------------------------------------------------
logoutHashPattern = "<a href=\"login.php%?do=logout&amp;logouthash=(.-)\">"

-------------------------------------------------------------------------------
-- securityTokenPattern
-- Purpose: Pattern for retrieving the session security token
-------------------------------------------------------------------------------
securityTokenPattern = "var SECURITYTOKEN = \"(.-)\";"

-------------------------------------------------------------------------------
-- thisSession
-- Purpose: Currently used session, retrieved by other modules by using
--			session.getActiveSession()
-------------------------------------------------------------------------------
local thisSession = nil

-------------------------------------------------------------------------------
-- facepunch.getActiveSession()
-- Purpose: Returns the currently selected session
-- Output: session
-------------------------------------------------------------------------------
function getActiveSession()
	return thisSession
end

-------------------------------------------------------------------------------
-- facepunch.getSecurityToken()
-- Purpose: Sets the session to be used by the FPAPI
-------------------------------------------------------------------------------
function setActiveSession( session )
	thisSession = session
end

-------------------------------------------------------------------------------
-- facepunch.getSecurityToken()
-- Purpose: Get the current security token, returns 0 and the token if
--			successful, otherwise returns 1 and nil
-- Output: error code, string token
-------------------------------------------------------------------------------
function getSecurityToken()
	local r, c = http.get( facepunch.rootURL, thisSession )
	if ( c == 200 ) then
		return 0, string.match( r, securityTokenPattern )
	else
		return 1, nil
	end
end

-------------------------------------------------------------------------------
-- session
-- Purpose: Class index
-------------------------------------------------------------------------------
local session = {}

-------------------------------------------------------------------------------
-- __metatable
-- Purpose: Class metatable
-------------------------------------------------------------------------------
__metatable = {
	__index = session,
	__type = "session"
}

-------------------------------------------------------------------------------
-- session.new()
-- Purpose: Creates a new session object
-- Output: session
-------------------------------------------------------------------------------
function new( username, password )
	local t = {
		username = username,
		password = password,
		cookie = nil
	}
	setmetatable( t, __metatable )
	return t
end

-------------------------------------------------------------------------------
-- session()
-- Purpose: Shortcut to session.new()
-- Output: session
-------------------------------------------------------------------------------
local metatable = {
	__call = function( _, ... )
		return new( ... )
	end
}
setmetatable( _M, metatable )

-------------------------------------------------------------------------------
-- login()
-- Purpose: Log the user in, returns 0 if successful, returns 1 if unable to
--			login.
-- Output: error code
-------------------------------------------------------------------------------
function session:login()
	local error, securityToken = -1, ""
	while error ~= 0 do
		error, securityToken = getSecurityToken()
	end
	if ( securityToken == "guest" ) then
		local postFields = "" ..
		-- Username
		"vb_login_username=" .. self.username ..
		-- Password Hint
		"&vb_login_password_hint=" .. "Password" ..
		-- Password
		"&vb_login_password=" .. self.password ..
		-- ???
		"&s=" .. "" ..
		-- Cookieuser
		"&cookieuser=" .. "1" ..
		-- Securitytoken
		"&securitytoken=" .. securityToken ..
		-- Method
		"&do=" .. "login" ..
		-- Md5 Password
		"&vb_login_md5password=" .. "" ..
		"&vb_login_md5password_utf=" .. ""
		
		local r, c, cookie = facepunch.http.post( facepunch.rootURL .. "/" .. facepunch.loginPage .. "?do=login", nil, postFields )
		if ( c == 200 ) then
			self.cookie = cookie
			return 0
		else
			return 1
		end
	else
		return 1
	end
end

-------------------------------------------------------------------------------
-- logout()
-- Purpose: Log the user out, returns 0 if successful, returns 1 if unable to
--			logout.
-- Output: error code
-------------------------------------------------------------------------------
function session:logout()
	local r, c = http.get( facepunch.rootURL .. "/" .. facepunch.loginPage .. "?do=logout" )
	local logoutHash = ""
	if ( c == 200 ) then
		logoutHash = string.match( r, logoutHashPattern )
	else
		return 1
	end
	
	if ( logoutHash ~= "" ) then
		r, c = http.get( facepunch.rootURL .. "/" .. facepunch.loginPage .. "?do=logout&logouthash=" .. logoutHash )
		return c == 200 and 0 or 1
	else
		return 1
	end
end

-------------------------------------------------------------------------------
-- member:__tostring()
-- Purpose: Returns a string representation of a session
-- Output: string
-------------------------------------------------------------------------------
function __metatable:__tostring()
	if not self.username then return "invalid session" end
	return "session: " .. self.username
end
