local table_ex = {}

function table_ex.count(tbl) expects "table"	
	local count = 0
	for k,v in pairs(tbl) do
		count = count + 1
	end
	
	return count
end

function table_ex.remove_value(tbl, val) expects("table", "any")
	for k, v in pairs(tbl) do
		if v == val then
			table.remove(tbl, k)
		end
	end
end

function table_ex.is_empty(tbl) expects "table"	
	return next(tbl) == nil
end

function table_ex.has_key(tbl, key) expects ("table", "any")
	return tbl[key] ~= nil
end

function table_ex.has_value(tbl, value) expects ("table", "any")	
	for k,v in pairs(tbl) do
		if v == value then
			return true, k
		end
	end
	return false, nil
end


-- Table to string
function to_lua_value(var, notable)
	local val = tostring(var)
	
	if type(var) == "string" then
		val = val:gsub("\\", "\\\\")
		val = val:gsub("\n", "\\n")
		val = val:gsub("\t", "\\t")
		val = val:gsub("\r", "\\r")
		val = val:gsub("\"", "\\\"")
		
		val = "\"" .. val .. "\""
	elseif type(var) == "table" and not notable then
		return to_lua_table(var)
	end
	
	return val
end

local function to_lua_table_key(key)
	if type(key) == "string" then
		if key:match("[A-z_][A-z_0-9]*") == key then
			return key
		end
		return "[" .. to_lua_value(key) .. "]"
	else
		return "[" .. to_lua_value(key) .. "]"
	end
end

local function to_lua_table(tbl, depth, done)
	if table.is_empty(tbl) then return "{}" end
	
	depth = depth or 1
	done = done or {}
	done[tbl] = true
	
	if depth > 1024 then return "..." end
	
	local ret = "{\n"
	local tabs = string.rep("\t", depth)
	
	for k, v in pairs(tbl) do
		ret = ret .. tabs .. to_lua_table_key(k) .. " = "
		
		if type(v) ~= "table" or done[v] then
			ret = ret .. to_lua_value(v, true)
		else
			ret = ret .. to_lua_table(v, depth + 1, done)
		end
		
		ret = ret .. ",\n"
	end
	
	-- remove last comma
	ret = ret:sub(1, ret:len() - 2) .. "\n"
	
	tabs = string.rep("\t", depth - 1)
	ret = ret .. tabs .. "}"
	return ret
end

function table_ex.to_string(tbl) expects "table"
	return to_lua_table(tbl)
end


do
	--[[
		Save Table to File/Stringtable
		Load Table from File/Stringtable
		v 0.94
	
		Lua 5.1 compatible
	
		Userdata and indices of these are not saved
		Functions are saved via string.dump, so make sure it has no upvalues
		References are saved
		----------------------------------------------------
		table.save( table [, filename] )
	
		Saves a table so it can be called via the table.load function again
		table must a object of type 'table'
		filename is optional, and may be a string representing a filename or true/1
	
		table.save( table )
			on success: returns a string representing the table (stringtable)
			(uses a string as buffer, ideal for smaller tables)
		table.save( table, true or 1 )
			on success: returns a string representing the table (stringtable)
			(uses io.tmpfile() as buffer, ideal for bigger tables)
		table.save( table, "filename" )
			on success: returns 1
			(saves the table to file "filename")
		on failure: returns as second argument an error msg
		----------------------------------------------------
		table.load( filename or stringtable )
	
		Loads a table that has been saved via the table.save function
	
		on success: returns a previously saved table
		on failure: returns as second argument an error msg
		----------------------------------------------------
	
		chillcode, http://lua-users.org/wiki/SaveTableToFile
		Licensed under the same terms as Lua itself.
	]]
	-- declare local variables
	--// exportstring( string )
	--// returns a "Lua" portable version of the string
	local function exportstring( s )
		s = string.format( "%q",s )
		-- to replace
		s = string.gsub( s,"\\\n","\\n" )
		s = string.gsub( s,"\r","\\r" )
		s = string.gsub( s,string.char(26),"\"..string.char(26)..\"" )
		return s
	end
	--// The Save Function
	function table_ex.save(  tbl,filename )
		local charS,charE = "	","\n"
		local file,err
		-- create a pseudo file that writes to a string and return the string
		if not filename then
			file =  { write = function( self,newstr ) self.str = self.str..newstr end, str = "" }
			charS,charE = "",""
		-- write table to tmpfile
		elseif filename == true or filename == 1 then
			charS,charE,file = "","",io.tmpfile()
		-- write table to file
		-- use io.open here rather than io.output, since in windows when clicking on a file opened with io.output will create an error
		else
			file,err = io.open( filename, "w" )
			if err then return _,err end
		end
		-- initiate variables for save procedure
		local tables,lookup = { tbl },{ [tbl] = 1 }
		file:write( "return {"..charE )
		for idx,t in ipairs( tables ) do
			if filename and filename ~= true and filename ~= 1 then
				file:write( "-- Table: {"..idx.."}"..charE )
			end
			file:write( "{"..charE )
			local thandled = {}
			for i,v in ipairs( t ) do
				thandled[i] = true
				-- escape functions and userdata
				if type( v ) ~= "userdata" then
					-- only handle value
					if type( v ) == "table" then
						if not lookup[v] then
							table.insert( tables, v )
							lookup[v] = #tables
						end
						file:write( charS.."{"..lookup[v].."},"..charE )
					elseif type( v ) == "function" then
						file:write( charS.."loadstring("..exportstring(string.dump( v )).."),"..charE )
					else
						local value =  ( type( v ) == "string" and exportstring( v ) ) or tostring( v )
						file:write(  charS..value..","..charE )
					end
				end
			end
			for i,v in pairs( t ) do
				-- escape functions and userdata
				if (not thandled[i]) and type( v ) ~= "userdata" then
					-- handle index
					if type( i ) == "table" then
						if not lookup[i] then
							table.insert( tables,i )
							lookup[i] = #tables
						end
						file:write( charS.."[{"..lookup[i].."}]=" )
					else
						local index = ( type( i ) == "string" and "["..exportstring( i ).."]" ) or string.format( "[%d]",i )
						file:write( charS..index.."=" )
					end
					-- handle value
					if type( v ) == "table" then
						if not lookup[v] then
							table.insert( tables,v )
							lookup[v] = #tables
						end
						file:write( "{"..lookup[v].."},"..charE )
					elseif type( v ) == "function" then
						file:write( "loadstring("..exportstring(string.dump( v )).."),"..charE )
					else
						local value =  ( type( v ) == "string" and exportstring( v ) ) or tostring( v )
						file:write( value..","..charE )
					end
				end
			end
			file:write( "},"..charE )
		end
		file:write( "}" )
		-- Return Values
		-- return stringtable from string
		if not filename then
			-- set marker for stringtable
			return file.str.."--|"
		-- return stringttable from file
		elseif filename == true or filename == 1 then
			file:seek ( "set" )
			-- no need to close file, it gets closed and removed automatically
			-- set marker for stringtable
			return file:read( "*a" ).."--|"
		-- close file and return 1
		else
			file:close()
			return 1
		end
	end

	--// The Load Function
	function table_ex.load( sfile )
		-- catch marker for stringtable
		if string.sub( sfile,-3,-1 ) == "--|" then
			tables,err = loadstring( sfile )
		else
			tables,err = loadfile( sfile )
		end
		if err then return _,err
		end
		tables = tables()
	
		if #tables == nil then return nil end
	
		for idx = 1,#tables do
			local tolinkv,tolinki = {},{}
			for i,v in pairs( tables[idx] ) do
				if type( v ) == "table" and tables[v[1]] then
					table.insert( tolinkv,{ i,tables[v[1]] } )
				end
				if type( i ) == "table" and tables[i[1]] then
					table.insert( tolinki,{ i,tables[i[1]] } )
				end
			end
			-- link values, first due to possible changes of indices
			for _,v in ipairs( tolinkv ) do
				tables[idx][v[1]] = v[2]
			end
			-- link indices
			for _,v in ipairs( tolinki ) do
				tables[idx][v[2]],tables[idx][v[1]] =  tables[idx][v[1]],nil
			end
		end
		return tables[1]
	end
end


return table_ex
