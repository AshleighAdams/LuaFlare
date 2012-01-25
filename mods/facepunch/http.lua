-------------------------------------------------------------------------------
-- HTTP wrapper module
-- Facepunch Lua API
-- Authors: Andrew McWatters
--			Gran PC
--			Gregor Steiner
-------------------------------------------------------------------------------
local error = error

module( "facepunch.http" )

-------------------------------------------------------------------------------
-- http.get()
-- Purpose: The get wrapper function for the facepunch module. All retrieval
--			functions rely on this wrapper for parsing. It must return the full
--			page if possible, a status code (200 OK), and cookie data if
--			possible.
-- Input: URL - URL to get
--		  session - session object to use, or nil
-- Output: document, status code, cookie
-------------------------------------------------------------------------------
function get( URL, session )
	error( "facepunch.http.get was not implemented!" )
end

-------------------------------------------------------------------------------
-- http.post()
-- Purpose: The post wrapper function for the facepunch module. All submission
--			functions rely on this wrapper for interaction. It must return the
--			full page if possible, a status code (200 OK), and cookie data if
--			possible.
-- Input: URL - URL to post to
--		  session - session object to use, or nil
--		  postData - table of POST information
-- Output: document, status code, cookie
-------------------------------------------------------------------------------
function post( URL, session, postData )
	error( "facepunch.http.post was not implemented!" )
end
