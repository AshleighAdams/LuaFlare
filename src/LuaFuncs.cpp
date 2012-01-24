#include "LuaFuncs.h"
#include <stdio.h>
#include <sys/stat.h>


int l_Print(lua_State* L)
{
	const char* str = luaL_checkstring(L, 1);
	printf(str);
	
	return 0;
}


void PrintTable(lua_State *L)
{
    lua_pushnil(L);

    while(lua_next(L, -2) != 0)
    {
        if(lua_isstring(L, -1))
          printf("%s = %s\n", lua_tostring(L, -2), lua_tostring(L, -1));
        else if(lua_isnumber(L, -1))
          printf("%s = %d\n", lua_tostring(L, -2), lua_tonumber(L, -1));
        else if(lua_istable(L, -1))
          PrintTable(L);

        lua_pop(L, 1);
    }
}

int l_DirExists(lua_State *L)
{
	const char* str = luaL_checkstring(L, 1);
	
	struct stat st;
	bool exists = stat(str, &st) == 0;
	
	lua_pushboolean(L, exists);
	return 1;
}

int l_FileExists(lua_State *L)
{
	return 0;
}
