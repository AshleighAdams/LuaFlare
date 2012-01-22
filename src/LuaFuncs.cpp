#include "LuaFuncs.h"
#include <stdio.h>

int l_Print(lua_State* L)
{
	const char* str = luaL_checkstring(L, 1);
	printf(str);
	
	return 0;
}
