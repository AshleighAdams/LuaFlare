-------------------------------------------------------------------------------
-- URL module
-- Facepunch Lua API
-- Authors: Andrew McWatters
--			Gran PC
--			Gregor Steiner
-------------------------------------------------------------------------------
local string = string
local tonumber = tonumber

module( "facepunch.url" )

-------------------------------------------------------------------------------
-- url.escape()
-- Purpose: Encodes a string into its escaped hexadecimal representation
-- Input: s - binary string to be encoded
-- Output: escaped representation of string binary
-------------------------------------------------------------------------------
function escape( s )
	return string.gsub( s, "([^A-Za-z0-9_])", function( c )
		return string.format( "%%%02x", string.byte( c ) )
	end )
end

-------------------------------------------------------------------------------
-- url.unescape()
-- Purpose: Decodes a string into its unescaped representation
-- Input: s - binary string to be decoded
-- Output: unescaped representation of string binary
-------------------------------------------------------------------------------
function unescape( s )
    return string.gsub( s, "%%(%x%x)", function( hex )
        return string.char( tonumber( hex, 16 ) )
    end )
end
