#include "HandelConnection.h"
#include <functional>
#include <iostream>
#include <fstream>

using namespace std;

CConnectionHandler::CConnectionHandler()
{
	
}
CConnectionHandler::~CConnectionHandler()
{
}


// This was going to be a lambada but, well, I guess not as you cant pass a labada function that captures a var to a funciton pointer...........
lua_State* g_pLs = 0;
int SetLuaConnectionValues(void *cls, enum MHD_ValueKind kind, const char *key, const char *value)
{
	const char* type;
	
	switch(kind)
	{
	case MHD_GET_ARGUMENT_KIND:
		type = "GET";
		break;
	case MHD_HEADER_KIND:
		type = "HEADER";
		break;
	case MHD_COOKIE_KIND:
		type = "COOKIE";
		break;
	case MHD_POSTDATA_KIND:
		type = "POST";
		break;
	case MHD_RESPONSE_HEADER_KIND:
		type = "RHEADER";
		break;
	case MHD_FOOTER_KIND:
		type = "FOOTER";
		break;
	default:
		return MHD_YES;
	}
	
	lua_pushstring(g_pLs, type); 		// Push the string
	lua_gettable(g_pLs, -2);			// Get the table the corrosponds to it, and put it on the stack
		lua_pushstring(g_pLs, key);		// Push key and value to the stack
		lua_pushstring(g_pLs, value);
		lua_rawset(g_pLs, -3);			// Tell lua to add them to the table
	lua_pop(g_pLs, 1); 					// I don't recall which this pops (table or string(type)); it's one of them...
	
	return MHD_YES;
}

void CConnectionHandler::Handel(connection_t* connection, MHD_Connection* mhdcon, todo_t& todo)
{
	LuaCreator LC;
	
	if(!LC.TrySetup(connection, mhdcon, todo))
	{
		connection->errcode = MHD_HTTP_INTERNAL_SERVER_ERROR;
		return;
	}
	
	lua_State* L = LC.GetState();
	
	MHD_KeyValueIterator itt_key = &SetLuaConnectionValues;
	
	{
		LOCK;
		g_pLs = L;
		MHD_get_connection_values(mhdcon, MHD_HEADER_KIND, 				itt_key, NULL);
		MHD_get_connection_values(mhdcon, MHD_COOKIE_KIND, 				itt_key, NULL);
		MHD_get_connection_values(mhdcon, MHD_POSTDATA_KIND, 			itt_key, NULL);
		MHD_get_connection_values(mhdcon, MHD_GET_ARGUMENT_KIND, 		itt_key, NULL);
		MHD_get_connection_values(mhdcon, MHD_FOOTER_KIND, 				itt_key, NULL);
		MHD_get_connection_values(mhdcon, MHD_RESPONSE_HEADER_KIND, 	itt_key, NULL);
	}
	
	
	// 1 argument, 1 result
	// The lock is removed so that many threads can run at the same time.
	if (lua_pcall(L, 1, 1, 0)) 
	{
		printf("error running function `main': %s\n", lua_tostring(L, -1));
		connection->response = "Lua error!";
		connection->errcode = MHD_HTTP_INTERNAL_SERVER_ERROR;
		return;
	}
	else
	{
		connection->response = LC.GetStringFromTable("response");
		
		// TODO: Clean this bit up
		lua_pushstring(L, "response_file");
		{
			lua_gettable(L, -2);

			if(lua_isstring(L, -1))
			{
				const char* filename = lua_tostring(L, -1);
				
				ifstream ifs(filename, ios::binary);
				
				if(ifs.is_open())
				{
					ifs.seekg(0, ios::end);
					int filesize = ifs.tellg();
					ifs.seekg(0, ios::beg);

					char* contents = new char[filesize];
					ifs.read(contents, filesize);
					
					ifs.close();
					todo.FileDataInstead = contents;
					todo.FileDataLength = filesize;
					
					connection->errcode = MHD_HTTP_OK;
				}else{
					connection->errcode = MHD_HTTP_NOT_FOUND; // con.errcode will overide this, so if you want it to use this, set it to nil
				}
			}
			
		}
		lua_pop(L, 1); // "response_file"
		
		connection->errcode = (int)LC.GetNumberFromTable("errcode");
		
		lua_pushstring(L, "response_headers");
		{
			LC.ItterateTable([&](string k, string v)
			{
				todo.response_headers.insert(ResponseHeadersMap::value_type(k, v));
			});
		}
		lua_pop(L, 1); // "response_headers"
		
		
		lua_pushstring(L, "set_cookies");
		{
			LC.ItterateTable([&](string k, string v)
			{
				todo.set_cookies.insert(ResponseHeadersMap::value_type(k, v));
			});
		}
		lua_pop(L, 1); // "set_cookies"
	}
	
	lua_pop(L, 1); // The retun table
	
	int stackpos = lua_gettop(L);
	if(stackpos)
		printf("WARNING: stack not at 0 (%i)\n", stackpos);
}
