#include "HandelConnection.h"

CConnectionHandler::CConnectionHandler()
{
	Failed = false;
	
	l = lua_open();
		
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

void CConnectionHandler::Handel(connection_t* connection)
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
	printf("Stack is at: %i\n", lua_gettop(l));
}
