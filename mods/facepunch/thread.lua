-------------------------------------------------------------------------------
-- Thread module
-- Facepunch Lua API
-- Authors: Andrew McWatters
--			Gran PC
--			Gregor Steiner
-------------------------------------------------------------------------------
local error = error
local facepunch = require( "facepunch" )
local http = require( "facepunch.http" )
local member = require( "facepunch.member" )
local post = require( "facepunch.post" )
local pairs = pairs
local session = require( "facepunch.session" )
local string = string
local table = table
local tonumber = tonumber
local url = require( "facepunch.url" )

module( "facepunch.thread" )

-------------------------------------------------------------------------------
-- canGuestViewPagePattern
-- Purpose: Pattern for detecting if guests can view a page, or if a session is
--			required to view
-------------------------------------------------------------------------------
canGuestViewPagePattern = "" ..
"blocksubhead\"><center>Sorry %- You can't view this page!"

-------------------------------------------------------------------------------
-- threadPageMemberPattern
-- Purpose: Pattern for filling member objects on a thread page. Below is what
--			each part of the pattern represents
-------------------------------------------------------------------------------
threadPageMemberPattern = "" ..
-- User ID
"username_container.-href=\"members/(%d+)" ..
-- Username
".-title=\"(.-) is " ..
-- Online Status
"(.-)line" ..
-- Displayed Username
".-\">(.-)</a>" ..
-- Usertitle
".-\"usertitle\">(.-)</span>" ..
-- Avatar
".-\"userdata\">.-<a .->(.-)</a>" ..
-- Join Date
".-\"userstats\">(.-)<br />" ..
-- Post Count
".-(.-) Posts.-</div>" ..
-- Social Links
".-\"imlinks\">(.-)</div>"

-------------------------------------------------------------------------------
-- memberSocialLinkPattern
-- Purpose: Pattern for filling the links table on a member from a thread page
-------------------------------------------------------------------------------
memberSocialLinkPattern = "" ..
"href=\"(.-)\"><img src=\"/fp/social/(.-)%."

-------------------------------------------------------------------------------
-- threadPagePostPattern
-- Purpose: Pattern for filling post objects on a thread page
-- It also gets the entire post body, which is necessary for the
-- postRatingResultSpanPattern, since posts without any ratings won't have a
-- rating_results span, and then this pattern wouldn't return those posts
-------------------------------------------------------------------------------
threadPagePostPattern = "" ..
-- Post Beginning
"<li class=\"postbitlegacy .- id=\"post_" ..
-- Post ID
"(.-)\">.-(" ..
-- Post Date
".-\"date\">(.-)</span>" ..
-- Link to Post
".-post%d-\" href=\"(.-)\"" ..
-- Post Number
".-postcount%d-\" name=\"(.-)\"" ..
-- End
".-</li>)"

-------------------------------------------------------------------------------
-- postRatingResultSpanPattern
-- Purpose: Pattern for getting the rating_results div, which may not be there
-- if the post has no ratings.
-------------------------------------------------------------------------------
postRatingResultSpanPattern = "" ..
"class=\"rating_results\" id=\"rating_.-\">.-<span>(.-)%(list%)</a>.-</span>"

-------------------------------------------------------------------------------
-- postRatingResultPattern
-- Purpose: Pattern for filling the ratings table on a post
-------------------------------------------------------------------------------
postRatingResultPattern = "" ..
"<img src=\".-\" alt=\"(.-)\" />.-<strong>(%d-)</strong>"

-------------------------------------------------------------------------------
-- postRatingKeyDivPattern
-- Purpose: Pattern for getting the postrating div, which is not there if you
-- are not logged in.
-------------------------------------------------------------------------------
postRatingKeyDivPattern = "" ..
"class=\"postrating\" id=\"ratingcontrols_post_.-\">(.-)</div>"

-------------------------------------------------------------------------------
-- postRatingKeyPattern
-- Purpose: Pattern for filling the rating key table on a post
-------------------------------------------------------------------------------
postRatingKeyPattern = "" ..
"<a href=\"#\".-RatePost%( '.-', '.-', '(.-)' %);\"><img src=\".-\" alt=\"(.-)\" /></a>"

-------------------------------------------------------------------------------
-- threadPageWhosReadingPattern
-- Purpose: Pattern for finding users browsing a thread
-------------------------------------------------------------------------------
threadPageWhosReadingPattern = "" ..
"whos_reading.-<script"

-------------------------------------------------------------------------------
-- threadPageMembersReadingPattern
-- Purpose: Pattern for filling partial member objects from users reading a
--			thread page. Below is what each part of the pattern represents
-------------------------------------------------------------------------------
threadPageMembersReadingPattern = "" ..
-- User ID
"username.-href=\"members/(%d+)" ..
-- Displayed Username
".-\">(.-)</a>"

-------------------------------------------------------------------------------
-- threadNamePattern
-- Purpose: Pattern for getting the threads name
-------------------------------------------------------------------------------
threadNamePattern = "" ..
"<title> (.-)</title>"

-------------------------------------------------------------------------------
-- threadPaginationPattern
-- Purpose: Pattern for retrieving pagination info
-------------------------------------------------------------------------------
threadPaginationPattern = "" ..
"pagination .-Page (%d+) of (%d+)"

-------------------------------------------------------------------------------
-- thread.canGuestViewPage()
-- Purpose: Returns true if a session is not required to view the page
-- Input: threadPage - string of the requested page
-- Output: boolean
-------------------------------------------------------------------------------
function canGuestViewPage( threadPage )
	return string.match( threadPage, canGuestViewPagePattern ) == nil and true or false
end

-------------------------------------------------------------------------------
-- thread.getMembersInPage()
-- Purpose: Returns all members that have posted on a given thread page, first
--			returns 0 if there are no errors or 1 in case of errors
-- Input: threadPage - string of the requested page
-- Output: table of members
-------------------------------------------------------------------------------
function getMembersInPage( threadPage )
	local t = {}
	local matched = false
	for userID,
		username,
		status,
		displayedUsername,
		usertitle,
		avatar,
		joinDate,
		postCount,
		links in string.gmatch( threadPage, threadPageMemberPattern ) do
		for _, v in pairs( t ) do
			if ( v.username == username ) then
				matched = true
			end
		end
		if ( not matched ) then
			local member			= member()
			member.userID			= userID
			member.username			= username
			member.online			= status == "on"
			if ( username == displayedUsername ) then
				member.usergroup	= "Registered User"
			elseif ( string.find( displayedUsername, "<font color=\"red\">" ) ) then
				member.usergroup	= "Banned"
			elseif ( string.find( displayedUsername, "#A06000" ) ) then
				member.usergroup	= "Gold Member"
			elseif ( string.find( displayedUsername, "#00aa00" ) ) then
				member.usergroup	= "Moderator"
			elseif ( string.find( displayedUsername, "<span class=\"boing\">") ) then
				member.usergroup	= "Administrator"
			end
			member.usertitle		= string.gsub( usertitle, "^%s*(.-)%s*$", "%1" )
			if ( string.find( member.usertitle, "<span" ) ) then
				member.usertitle	= member.usertitle .. "</span>"
			end
			if ( member.usertitle == "" ) then
				member.usertitle	= nil
			end
			avatar					= string.gsub( avatar, "^%s*(.-)%s*$", "%1" )
			if ( avatar == "" ) then
				member.avatar		= nil
			else
				member.avatar		= facepunch.rootURL .. string.match( avatar, ".-img src=\"(.-)\"" )
			end
			member.joinDate			= string.gsub( joinDate, "^%s*(.-)%s*$", "%1" )
			member.postCount		= postCount
			member.postCount		= string.gsub( member.postCount, "^%s*(.-)%s*$", "%1" )
			member.postCount		= tonumber( string.gsub( member.postCount, ",", "" ), 10 )

			member.links = {}
			local hasLinks = false
			for url, name in string.gmatch( links, memberSocialLinkPattern ) do
				if ( hasLinks == false ) then hasLinks = true end
				member.links[ name ] = url
			end
			if ( not hasLinks ) then member.links = nil end
			table.insert( t, member )
		else
			matched = false
		end
	end
	return t
end

-------------------------------------------------------------------------------
-- thread.getMembersReading()
-- Purpose: Returns a partial member object for all members browsing a thread
--			and the number of guests browsing if any
-- Input: threadPage - string of the requested page
-- Output: table of members plus a guest key and amount
-------------------------------------------------------------------------------
function getMembersReading( threadPage )
	local t = {}
	local whosReading = string.match( threadPage, threadPageWhosReadingPattern )
	for userID, displayedUsername in string.gmatch( whosReading, threadPageMembersReadingPattern ) do
		local member	= member()
		member.userID	= userID
		member.online	= true
		if ( string.find( displayedUsername, "<font color=\"red\">" ) ) then
			member.username		= string.gsub( displayedUsername, "<font color=\"red\">", "" )
			member.username		= string.gsub( member.username, "</font>", "" )
			member.usergroup	= "Banned"
		elseif ( string.find( displayedUsername, "#A06000" ) ) then
			member.username		= string.gsub( displayedUsername, "<strong><font color=\"#A06000\">", "" )
			member.username		= string.gsub( member.username, "</font></strong>", "" )
			member.usergroup	= "Gold Member"
		elseif ( string.find( displayedUsername, "#00aa00" ) ) then
			member.username		= string.gsub( displayedUsername, "<span style=\"color:#00aa00;font%-weight:bold;\">", "" )
			member.username		= string.gsub( member.username, "</span>", "" )
			member.usergroup	= "Moderator"
		elseif ( string.find( displayedUsername, "<span class=\"boing\">") ) then
			member.username		= string.gsub( displayedUsername, "<span class=\"boing\">", "" )
			member.username		= string.gsub( member.username, "</span>", "" )
			member.usergroup	= "Administrator"
		else
			member.username		= displayedUsername
			member.usergroup	= "Registered User"
		end
		table.insert( t, member )
	end
	local guests = string.match( threadPage, "%((%d+) guests%)" )
	if ( guests ) then
		t.guests = tonumber( guests )
	end
	return t
end

-------------------------------------------------------------------------------
-- thread.getName()
-- Purpose: Returns the name of the thread
-- Input: threadPage - string of the requested page
-- Output: name of thread
-------------------------------------------------------------------------------
function getName( threadPage )
	return string.match( threadPage, threadNamePattern )
end

-------------------------------------------------------------------------------
-- thread.getPage()
-- Purpose: Returns 0 if the page is retrieved successfully, then the thread
--			page by ID and page number, if provided, otherwise it returns 1 and
--			nil
-- Input: threadID - ID of the thread to get
--		  pageNumber - number of the page to get
-- Output: error code, thread page
-------------------------------------------------------------------------------
function getPage( threadID, pageNumber )
	pageNumber = pageNumber or ""
	if ( pageNumber ~= "" ) then
		pageNumber = "/" .. pageNumber
	end
	local r, c = http.get( facepunch.baseURL .. "/threads/" .. threadID .. pageNumber, session.getActiveSession() )
	if ( c == 200 ) then
		return 0, r
	else
		return 1, nil
	end
end

-------------------------------------------------------------------------------
-- thread.getPaginationInfo()
-- Purpose: Returns the page number of the thread page provided, and the total
--			number of pages in the thread
-- Input: threadPage - string of the requested page
-- Output: current page number, page count
-------------------------------------------------------------------------------
function getPaginationInfo( threadPage )
	local currentPage, pageCount = string.match( threadPage, threadPaginationPattern )
	if ( currentPage == nil and pageCount == nil ) then return 1, 1 end
	return tonumber( currentPage ), tonumber( pageCount )
end

-------------------------------------------------------------------------------
-- thread.getPostsInPage()
-- Purpose: Returns all posts on a given thread page, first returns 0 if there
--			are no errors or 1 in case of errors
-- Input: threadPage - string of the requested page
-- Output: table of posts
-------------------------------------------------------------------------------
function getPostsInPage( threadPage )
	local t = {}
	for postID,
		fullPost,
		postDate,
		link,
		postNumber
		in string.gmatch( threadPage, threadPagePostPattern ) do
		local post		= post()
		post.postID		= postID
		post.postDate	= postDate
		post.link		= facepunch.baseURL .. string.gsub( link, "&amp;", "&" )
		post.postNumber	= postNumber

		local postRatings = string.match( fullPost, postRatingResultSpanPattern )
		if ( postRatings ) then
			post.postRatings = {}
			for name, amount in string.gmatch( postRatings, postRatingResultPattern ) do
				post.postRatings[ name ] = tonumber( amount )
			end
		end
		
		local postRatingKeys = string.match( fullPost, postRatingKeyDivPattern )
		if ( postRatingKeys ) then
			post.postRatingKeys = {}
			for key, rating in string.gmatch( postRatingKeys, postRatingKeyPattern ) do
				post.postRatingKeys[ rating ] = key
			end
		end

		table.insert( t, post )
	end
	return t
end

-------------------------------------------------------------------------------
-- thread.reply()
-- Purpose: Post a new reply
-- Input: threadID - ID of the thread to reply to
--		  postData - post
--		  securityToken - security token for this request
-------------------------------------------------------------------------------
function reply( threadID, postData, securityToken )
	local postFields = "" ..
	-- Message Backup
	"&message_backup=" .. url.escape( postData ) ..
	-- Message
	"&message=" .. url.escape( postData ) ..
	-- WYSIWYG
	"&wysiwyg=" .. "0" ..
	-- ???
	"s=" .. "" ..
	-- Security Token
	"&securitytoken=" .. ( securityToken or "guest" ) ..
	-- Method
	"&do=" .. "postreply" ..
	-- ThreadID
	"&t=" .. threadID ..
	-- ???
	"&p=" .. "" ..
	-- Specified Post
	"&specifiedpost=" .. "0" ..
	-- Post Hash
	"&posthash=" .. "invalid posthash" ..
	-- Post Start Time
	"&poststarttime=" .. "0" ..
	-- Logged-in User (Not yet implemented)
	-- "&loggedinuser=" .. session.getActiveSession().userID ..
	-- ???
	"&multiquoteempty=" .. "" ..
	-- Submit Button
	-- We don't do this because we're an API.
	--"&sbutton=" .. "Submit Reply" ..
	-- Parse URLs
	"&parseurl" .. "1"

	local r, c = http.post( facepunch.rootURL .. "/" .. facepunch.newReplyPage .. "?do=postreply&t=" .. threadID, session.getActiveSession(), postFields )
	return c == 200 and 0 or 1
end
