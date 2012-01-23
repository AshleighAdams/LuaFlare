#include "HandelConnection.h"
#include <functional>

CConnectionHandler::CConnectionHandler()
{
	Failed = false;
	
	l = lua_open();
	
	luaL_openlibs(l);
	
	lua_pushcfunction(l, l_Print);
	lua_setglobal(l, "Print");
	
	if( luaL_loadfile(l, "main.lua") || lua_pcall(l, 0, 0, 0))
	{
		printf("error: %s", lua_tostring(l, -1));
		Failed = true;
		return;
	}
}
CConnectionHandler::~CConnectionHandler()
{
	lua_close(l);
}

typedef int(*KeysFn)(void *cls, enum MHD_ValueKind kind, const char *key, const char *value);

void CConnectionHandler::Handel(connection_t* connection, MHD_Connection* mhdcon)
{
	if(Failed)
		return;

	lua_getglobal(l, "main");
	if(!lua_isfunction(l,-1))
	{
		lua_pop(l,1);
		return;
	}
	
	lua_newtable(l);
	lua_pushstring(l, "url");
	lua_pushstring(l, connection->url.c_str());
	lua_rawset(l, -3);
	
	lua_pushstring(l, "method");
	lua_pushstring(l, connection->method.c_str());
	lua_rawset(l, -3);
	
	lua_pushstring(l, "version");
	lua_pushstring(l, connection->version.c_str());
	lua_rawset(l, -3);
	
	lua_pushstring(l, "response");
	lua_pushstring(l, connection->response.c_str());
	lua_rawset(l, -3);
	
	//lua_pushstring(l, "GET");
	//lua_newtable(l);
	//lua_rawset(l, -3);
	
	
	KeysFn pKeysFunc = [&](void *cls, enum MHD_ValueKind kind, const char *key, const char *value)
	{
		printf("\t%s\t%s (MTHD = %i)\n", key, value, kind);
		return MHD_YES;
	};
	
	MHD_KeyValueIterator itt_key = pKeysFunc;

	// Now lets make it call our lambada
	MHD_get_connection_values(mhdcon, MHD_HEADER_KIND, itt_key, NULL);
	MHD_get_connection_values(mhdcon, MHD_COOKIE_KIND, itt_key, NULL);
	MHD_get_connection_values(mhdcon, MHD_POSTDATA_KIND, itt_key, NULL);
	MHD_get_connection_values(mhdcon, MHD_GET_ARGUMENT_KIND, itt_key, NULL);
	
	
	// 1 argument, 1 result
	if (lua_pcall(l, 1, 1, 0)) 
	{
		printf("error running function `main': %s\n", lua_tostring(l, -1));
		return;
	}
	
	lua_pushstring(l, "response");
	{
		lua_gettable(l, -2);

		if(lua_isstring(l, -1))
			connection->response = lua_tostring(l, -1);
		
	}
	lua_pop(l, 1); // "response"
	
	lua_pop(l, 1); // The retun table
	
	int stackpos = lua_gettop(l);
	if(stackpos)
		printf("WARNING: stack not at 0 (%i)\n", stackpos);
}
