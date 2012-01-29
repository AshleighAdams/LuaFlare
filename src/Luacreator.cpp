#include "HandelConnection.h"

#include "Luacreator.h"

using namespace std;

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
	
	lua_pushcfunction(m_L, l_Lock);
	lua_setglobal(m_L, "Lock"); // ModLock and not Lock so the main.lua can change it, set it to a func that calls the func, that way it prevents locking in a lock
	
	if(luaL_loadfile(m_L, "main.lua") || lua_pcall(m_L, 0, 0, 0))
	{
		printf("error: %s\n", lua_tostring(m_L, -1));
		return;
	}
	
	l_ResetMicroTime(m_L); // For the load time shit
	SetupLock(m_L);
}


#define CREATE_EMPTY_TABLE(name) \
	lua_pushstring(m_L, name); \
	lua_newtable(m_L); \
	lua_rawset(m_L, -3) \

bool LuaCreator::TrySetup(connection_t* connection, MHD_Connection* mhdcon, todo_t& todo)
{
	lua_getglobal(m_L, "main");
	if(!lua_isfunction(m_L, -1))
	{
		lua_pop(m_L, 1);
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
	FreeLock(m_L);
	
	lua_close(m_L);
	// Free the lua state here
}


lua_State* LuaCreator::GetState()
{
	return m_L;
}

string LuaCreator::GetStringFromTable(string key)
{
	string ret;
	lua_pushstring(m_L, key.c_str());
	
		lua_gettable(m_L, -2);
		if(lua_isstring(m_L, -1))
			ret = lua_tostring(m_L, -1);
		else
			ret = "";
	
	lua_pop(m_L, 1);
	return ret;
}

double LuaCreator::GetNumberFromTable(string key)
{
	int ret;
	lua_pushstring(m_L, key.c_str());
	
		lua_gettable(m_L, -2);
		if(lua_isnumber(m_L, -1))
			ret = lua_tonumber(m_L, -1);
		else
			ret = 0;
	
	lua_pop(m_L, 1);
	return ret;
}


void LuaCreator::ItterateTable(function<void(string k, string v)> callback)
{
	lua_gettable(m_L, -2);

	lua_pushnil(m_L);
	
	string k,v;
	
	while(lua_next(m_L, -2) != 0)
	{
		k = lua_tostring(m_L, -2);
		v = lua_tostring(m_L, -1);
		lua_pop(m_L, 1);
		callback(k, v);
	}
}

