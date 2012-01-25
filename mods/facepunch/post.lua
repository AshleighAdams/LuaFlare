-------------------------------------------------------------------------------
-- Post module and class definition
-- Facepunch Lua API
-- Authors: Andrew McWatters
--			Gran PC
--			Gregor Steiner
-------------------------------------------------------------------------------
local error = error
local facepunch = require( "facepunch" )
local setmetatable = setmetatable

module( "facepunch.post" )

-------------------------------------------------------------------------------
-- ratings
-- Purpose: Maps rating namings to rating IDs
-------------------------------------------------------------------------------
ratings = {
	[ "Agree" ]				= 1,
	[ "Disagree" ]			= 2,
	[ "Funny" ]				= 3,
	[ "Informative" ]		= 4,
	[ "Friendly" ]			= 5,
	[ "Useful" ]			= 6,
	[ "Optimistic" ]		= 7,
	[ "Artistic" ]			= 8,
	[ "Late" ]				= 9,
	[ "Bad Spelling" ]		= 10,
	[ "Bad Reading" ]		= 11,
	[ "Dumb" ]				= 12,
	[ "Zing" ]				= 13,
	[ "Programming King" ]	= 14,
	[ "Smarked" ]			= 15,
	[ "Lua King" ]			= 16,
	[ "Mapping King" ]		= 17,
	[ "Winner" ]			= 18,
	[ "Lua Helper" ]		= 19,
	[ "OIFY Pinknipple" ]	= 20,
	[ "Moustache" ]			= 21
}

-------------------------------------------------------------------------------
-- post
-- Purpose: Class index
-------------------------------------------------------------------------------
local post = {}

-------------------------------------------------------------------------------
-- __metatable
-- Purpose: Class metatable
-------------------------------------------------------------------------------
__metatable = {
	__index = post,
	__type = "post"
}

-------------------------------------------------------------------------------
-- post.new()
-- Purpose: Creates a new post object
-- Output: post
-------------------------------------------------------------------------------
function new()
	local t = {
		postID = nil,
		postDate = nil,
		link = nil,
		postNumber = nil,
		postRatings = nil,
		postRatingKeys = nil
	}
	setmetatable( t, __metatable )
	return t
end

-------------------------------------------------------------------------------
-- post()
-- Purpose: Shortcut to post.new()
-- Output: post
-------------------------------------------------------------------------------
local metatable = {
	__call = function( _, ... )
		return new( ... )
	end
}
setmetatable( _M, metatable )

-------------------------------------------------------------------------------
-- post:rate()
-- Purpose: Rates a post
-- Input: rating - name of the rating
--		  securityToken - security token for this request
-------------------------------------------------------------------------------
function post:rate( rating, securityToken )
	if ( ratings[ rating ] and self.postRatingKeys[ rating ] ) then
		local postFields = "" ..
		-- Method
		"do=" .. "rate_post" ..
		-- PostID
		"&postid=" .. self.postID ..
		-- Rating
		"&rating=" .. ratings[ rating ] ..
		-- Key
		"&key=" .. self.postRatingKeys[ rating ] ..
		-- Securitytoken
		"&securitytoken=" .. ( securityToken or "guest" )
		
		local r, c = facepunch.http.post( facepunch.rootURL .. "/" .. facepunch.ajaxPage, postFields )
		return c == 200 and 0 or 1
	else
		return 1
	end
end

-------------------------------------------------------------------------------
-- post:__tostring()
-- Purpose: __tostring metamethod for post
-------------------------------------------------------------------------------
function __metatable:__tostring()
	if not self.postID then return "invalid post" end
	return "post: " .. self.postID
end
