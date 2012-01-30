#include "HandelConnection.h"

#include "Luacreator.h"

using namespace std;

// Eh can't be arsed to move it above
lua_State* CreateState(string* err = 0, bool cached = true);

lua_State* g_PreCachedStates[PRECACHE_SIZE];
int g_PCpos = 0;
int g_GetPCpos = 0;
bool First = true;

using namespace std;

LuaCreator::LuaCreator()
{
	m_Failed = false;
	unsigned long msstart = GetMicroTime();
	
	// Attempt to load one from the prebuilt cache
	#ifdef PRECACHE
	{
		PC_LOCK;
		
		m_L = g_PreCachedStates[g_GetPCpos];
		g_PreCachedStates[g_GetPCpos] = 0; // Discard it // TODO: Can we reuse these?
		g_GetPCpos++;
		
		if(g_GetPCpos >= PRECACHE_SIZE)
			g_GetPCpos = 0;
		if(m_L)
		{
			ResetMicroTime(m_L, msstart); // More accurate than setting it after lua state created (that takes about ~1ms, so we precache it)
			SetupLock(m_L);
			return; // Woop, we got one from the cache!
		}
	}
	#endif
	
	string err;
	m_L = CreateState(&err, false);
	
	if(!m_L)
	{
		printf("error: %s\n", err.c_str());
		m_Failed = true;
		return;
	}
	
	// We do this now because the destructer will be called and resources need to be freed
	ResetMicroTime(m_L, msstart);
	SetupLock(m_L);
}


#define CREATE_EMPTY_TABLE(name) \
	lua_pushstring(m_L, name); \
	lua_newtable(m_L); \
	lua_rawset(m_L, -3) \

bool LuaCreator::TrySetup(connection_t* connection, MHD_Connection* mhdcon, todo_t& todo)
{
	if(m_Failed)
		return false;
	
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

lua_State* CreateState(string* err, bool cached)
{
	lua_State* m_L = lua_open();
	
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
	
	lua_pushboolean(m_L, cached);
	lua_setglobal(m_L, "PRECACHED");
	
	if(luaL_loadfile(m_L, "main.lua") || lua_pcall(m_L, 0, 0, 0))
	{
		if(err) // If they want to get a string to see if it cimnpleted then let them know what went wrong
			*err = lua_tostring(m_L, -1);
		return 0;
	}
	return m_L;
}

void PrecacheLuaStates()
{
	if(First)
	{
		for(int i = 0; i< PRECACHE_SIZE; i++)
			g_PreCachedStates[i] = CreateState();
		g_PCpos = 0;
		g_GetPCpos = 0;
		First = false;
	}
	
	PC_LOCK;
	
	while(true)
	{
		if(g_PCpos >= PRECACHE_SIZE || g_PCpos < 0)
			g_PCpos = 0;
		if(g_PCpos == g_GetPCpos)
			break;
		
		g_PreCachedStates[g_PCpos] = CreateState(); // We don't need to show errors here as the precache creation will fail flat out
		g_PCpos++;									// and will attempt to create one at request time thus regenerating the error and displaying it
	}
}
