#include "HandelConnection.h"

#include "Luacreator.h"

LuaCreator::LuaCreator()
{
	m_L = 0;
	
	m_L = lua_open();
	
	LUAJITSETUP(m_L);
	
	luaL_openlibs(m_L);
	//LoadMods(l);
	
	lua_pushcfunction(m_L, l_GetCurrentTime);
	lua_setglobal(m_L, "GetCurrentTime");
	
	lua_pushcfunction(m_L, l_ResetMicroTime);
	lua_setglobal(m_L, "ResetMicroTime");
	
	lua_pushcfunction(m_L, l_MicroTime);
	lua_setglobal(m_L, "GetMicroTime");
	
	lua_pushcfunction(m_L, l_Print);
	lua_setglobal(m_L, "Print");
	
	lua_pushcfunction(m_L, l_EscapeHTML);
	lua_setglobal(m_L, "EscapeHTML");
	
	lua_pushcfunction(m_L, l_DirExists);
	lua_setglobal(m_L, "DirExists");
	
	lua_pushcfunction(m_L, l_ParseLuaString);
	lua_setglobal(m_L, "ParseLuaString");
	
	lua_pushcfunction(m_L, l_GenerateSessionID);
	lua_setglobal(m_L, "GenerateSessionID");
	
	if(luaL_loadfile(m_L, "main.lua") || lua_pcall(m_L, 0, 0, 0))
	{
		printf("error: %s\n", lua_tostring(m_L, -1));
		return;
	}
	
	l_ResetMicroTime(m_L); // For the load time shit
}


#define CREATE_EMPTY_TABLE(name) \
	lua_pushstring(m_L, name); \
	lua_newtable(m_L); \
	lua_rawset(m_L, -3) \

bool LuaCreator::TrySetup(connection_t* connection, MHD_Connection* mhdcon, todo_t& todo)
{
	lua_getglobal(m_L, "main");
	if(!lua_isfunction(m_L,-1))
	{
		lua_pop(m_L,1);
		return false;
	}
	
	if(!lua_checkstack(m_L, 5)) // 5 should be enough
		return false;
	
	
	lua_newtable(m_L); // con table
	
	lua_pushstring(m_L, "starttime");
	lua_pushnumber(m_L, GetCurrentTime());
	lua_rawset(m_L, -3);
	
	lua_pushstring(m_L, "url");
	lua_pushstring(m_L, connection->url.c_str());
	lua_rawset(m_L, -3);
	
	lua_pushstring(m_L, "method");
	lua_pushstring(m_L, connection->method.c_str());
	lua_rawset(m_L, -3);
	
	lua_pushstring(m_L, "version");
	lua_pushstring(m_L, connection->version.c_str());
	lua_rawset(m_L, -3);
	
	lua_pushstring(m_L, "response");
	lua_pushstring(m_L, connection->response.c_str());
	lua_rawset(m_L, -3);
	
	lua_pushstring(m_L, "ip");
	lua_pushstring(m_L, connection->ip.c_str());
	lua_rawset(m_L, -3);
	
	CREATE_EMPTY_TABLE("GET");
	CREATE_EMPTY_TABLE("HEADER");
	CREATE_EMPTY_TABLE("COOKIE");
	CREATE_EMPTY_TABLE("POST");
	CREATE_EMPTY_TABLE("RHEADER");
	CREATE_EMPTY_TABLE("FOOTER");
	CREATE_EMPTY_TABLE("response_headers");
	CREATE_EMPTY_TABLE("set_cookies");
	
	return true;
}

#undef CREATE_EMPTY_TABLE

LuaCreator::~LuaCreator()
{
	if(!m_L) // If the state was never loaded, then do nothing
		return;
	
	MicroTime_Free(m_L);
	
	lua_close(m_L);
	// Free the lua state here
}


lua_State* LuaCreator::GetState()
{
	return m_L;
}

