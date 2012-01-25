
<?lua

include("inc/testinc.lua")

-- member.searchUser
-- usage: lua test\searchUser.lua

local facepunch	= require( "facepunch" )
local member	= facepunch.member
local session	= facepunch.session

-- Setup our connector
-- Use luasocket for this test
require( "connectors.luasocket" )

local username = GET.u
local password = GET.p

local thisSession = session( username, password )
write(false, ( "Logging in as " .. EscapeHTML(username) .. "...<br/>" ))
local error = -1
while error ~= 0 do
	error = thisSession:login()
end
session.setActiveSession( thisSession )

local error, securityToken = -1, nil
while error ~= 0 do
	error, securityToken = session.getSecurityToken()
end

local _, waywo = facepunch.thread.getPage(1151723, 66)
local posts = facepunch.thread.getPostsInPage(waywo)

for k, v in pairs(posts) do
	if tostring(v.postNumber) == "2631" then
		v:rate(facepunch.post.ratings.Dumb, securityToken)
		write("Rated dumb\n")
	end
end

?>
