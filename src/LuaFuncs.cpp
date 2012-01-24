#include "LuaFuncs.h"
#include <stdio.h>
#include <sys/stat.h>
#include <string>
using namespace std;

int l_Print(lua_State* L)
{
	const char* str = luaL_checkstring(L, 1);
	printf(str);
	
	return 0;
}

int l_Escape(lua_State* L)
{
	string in = luaL_checkstring(L, 1);
	
    string buf;
    buf.reserve(in.size());
    for(size_t pos = 0; pos != in.size(); ++pos)
    {
        switch(in[pos])
        {
            case '&':  buf.append("&amp;");		break;
            case '\"': buf.append("&quot;");	break;
            case '\'': buf.append("&apos;");	break;
            case '<':  buf.append("&lt;");		break;
            case '>':  buf.append("&gt;");		break;
           
           default:   buf.append(1, in[pos]);	break;
        }
    }
    in.swap(buf);
	
	lua_pushstring(L, in.c_str());
	return 1;
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
