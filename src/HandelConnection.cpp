#include "HandelConnection.h"
#include <functional>
#include <iostream>
#include <fstream>

using namespace std;

lua_State* GetState()
{
	lua_State* l = lua_open();
	
	LUAJITSETUP(l);
	
	luaL_openlibs(l);
	//LoadMods(l);
	
	lua_pushcfunction(l, l_GetCurrentTime);
	lua_setglobal(l, "GetCurrentTime");
	
	lua_pushcfunction(l, l_ResetMicroTime);
	lua_setglobal(l, "ResetMicroTime");
	
	lua_pushcfunction(l, l_MicroTime);
	lua_setglobal(l, "GetMicroTime");
	
	lua_pushcfunction(l, l_Print);
	lua_setglobal(l, "Print");
	
	lua_pushcfunction(l, l_EscapeHTML);
	lua_setglobal(l, "EscapeHTML");
	
	lua_pushcfunction(l, l_DirExists);
	lua_setglobal(l, "DirExists");
	
	lua_pushcfunction(l, l_ParseLuaString);
	lua_setglobal(l, "ParseLuaString");
	
	lua_pushcfunction(l, l_GenerateSessionID);
	lua_setglobal(l, "GenerateSessionID");
	
	if(luaL_loadfile(l, "main.lua") || lua_pcall(l, 0, 0, 0))
	{
		printf("error: %s\n", lua_tostring(l, -1));
		return 0;
	}
	return l;
}

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

#define CREATE_EMPTY_TABLE(name) \
	lua_pushstring(L, name); \
	lua_newtable(L); \
	lua_rawset(L, -3) \

void CConnectionHandler::Handel(connection_t* connection, MHD_Connection* mhdcon, todo_t& todo)
{
	lua_State* L = GetState();
	
	if(!L)
	{
		connection->errcode = MHD_HTTP_INTERNAL_SERVER_ERROR;
		return;
	}
	
	l_ResetMicroTime(L);
	
	lua_getglobal(L, "main");
	if(!lua_isfunction(L,-1))
	{
		lua_pop(L,1);
		MicroTime_Free(L);
		lua_close(L);
		return;
	}
		
	lua_newtable(L); // con table
	
	lua_pushstring(L, "starttime");
	lua_pushnumber(L, GetCurrentTime());
	lua_rawset(L, -3);
	
	lua_pushstring(L, "url");
	lua_pushstring(L, connection->url.c_str());
	lua_rawset(L, -3);
	
	lua_pushstring(L, "method");
	lua_pushstring(L, connection->method.c_str());
	lua_rawset(L, -3);
	
	lua_pushstring(L, "version");
	lua_pushstring(L, connection->version.c_str());
	lua_rawset(L, -3);
	
	lua_pushstring(L, "response");
	lua_pushstring(L, connection->response.c_str());
	lua_rawset(L, -3);
	
	lua_pushstring(L, "ip");
	lua_pushstring(L, connection->ip.c_str());
	lua_rawset(L, -3);
	
	CREATE_EMPTY_TABLE("GET");
	CREATE_EMPTY_TABLE("HEADER");
	CREATE_EMPTY_TABLE("COOKIE");
	CREATE_EMPTY_TABLE("POST");
	CREATE_EMPTY_TABLE("RHEADER");
	CREATE_EMPTY_TABLE("FOOTER");
	CREATE_EMPTY_TABLE("response_headers");
	CREATE_EMPTY_TABLE("set_cookies");
	
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
		MicroTime_Free(L);
		lua_close(L);
		return;
	}
	else
	{
		lua_pushstring(L, "response");
		{
			lua_gettable(L, -2);

			if(lua_isstring(L, -1))
				connection->response = lua_tostring(L, -1);
		}
		lua_pop(L, 1); // "response"
		
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
		
		lua_pushstring(L, "errcode");
		{
			lua_gettable(L, -2);

			if(lua_isnumber(L, -1))
				connection->errcode = (int)lua_tonumber(L, -1);
		}
		lua_pop(L, 1);
		
		lua_pushstring(L, "response_headers");
		{
			lua_gettable(L, -2);

			lua_pushnil(L);

			while(lua_next(L, -2) != 0)
			{
				todo.response_headers.insert(ResponseHeadersMap::value_type(lua_tostring(L, -2), lua_tostring(L, -1)));
				lua_pop(L, 1);
			}
		}
		lua_pop(L, 1); // "response_headers"
		
		lua_pushstring(L, "set_cookies");
		{
			lua_gettable(L, -2);

			lua_pushnil(L);

			while(lua_next(L, -2) != 0)
			{
				todo.set_cookies.insert(ResponseHeadersMap::value_type(lua_tostring(L, -2), lua_tostring(L, -1)));
				lua_pop(L, 1);
			}
		}
		lua_pop(L, 1); // "set_cookies"
	}
	
	lua_pop(L, 1); // The retun table
	
	MicroTime_Free(L);
	
	int stackpos = lua_gettop(L);
	lua_close(L);
	if(stackpos)
		printf("WARNING: stack not at 0 (%i)\n", stackpos);
}
