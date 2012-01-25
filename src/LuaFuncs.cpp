#include "LuaFuncs.h"
#include <stdio.h>
#include <sys/stat.h>
#include <string>
#include <iostream>
using namespace std;

int l_Print(lua_State* L)
{
	const char* str = luaL_checkstring(L, 1);
	cout << str;
	
	return 0;
}

int l_EscapeHTML(lua_State* L)
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

void PrintTable(lua_State *L, int Depth)
{
	char* tabs = new char[Depth + 1];
	
	for(int i = 0; i < Depth; i++)
		tabs[i] = '\t';
	tabs[Depth] = '\0';
	
	lua_pushnil(L);
	
    while(lua_next(L, -2) != 0)
    {
        if(lua_isstring(L, -1))
          printf("%s%s = %s\n", tabs, lua_tostring(L, -2), lua_tostring(L, -1));
        else if(lua_isnumber(L, -1))
          printf("%s%s = %d\n", tabs, lua_tostring(L, -2), lua_tonumber(L, -1));
        else if(lua_istable(L, -1))
		{
			printf("%s%s:\n", tabs, lua_tostring(L, -2));
			PrintTable(L, Depth + 1); // TODO: Refrence to self
		}

        lua_pop(L, 1);
    }
    
    delete [] tabs;
}

int l_PrintTable(lua_State *L)
{
    return 0;
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

#define PARSEMODE_OUTOFLUA 0
#define PARSEMODE_INLUA 1
#define PARSEMODE_INCOMMENT 2

// <?lua ?> support

int l_ParseLuaString(lua_State* L)
{
	string inlua = luaL_checkstring(L, 1);
	string outlua;
	
	outlua.reserve(inlua.size());

	int parsemode = PARSEMODE_OUTOFLUA;
	
	outlua += "write([[";
	
	unsigned int i = 0;
	while(i < inlua.length())
	{
		if(parsemode == PARSEMODE_OUTOFLUA)
		{
			while(i < inlua.length())
			{
				char x = inlua[i];
				if(x == '<' && inlua[i+1] == '?' && inlua[i+2] == 'l' && inlua[i+3] == 'u' && inlua[i+4] == 'a')
				{
					i += 5;
					outlua += "]])";
					parsemode = PARSEMODE_INLUA;
					break; // New parse mode!
				}
				else if(x == ']' && inlua[i+1] == ']')
				{
					outlua += "\\93\\93";
					i += 2;
				}
				else if(x == '[' && inlua[i+1] == '[')
				{
					outlua += "\\91\\91";
					i += 2;
				}
				else
				{
					outlua += x;
					i++;
				}
			}
		}
		else if(parsemode == PARSEMODE_INLUA)
		{
			while(i < inlua.length())
			{
				char x = inlua[i];
				
				if(x == '?' && inlua[i+1] == '>')
				{
					parsemode = PARSEMODE_OUTOFLUA;
					outlua += "write(false, [[";
					i+= 2;
					break;
				}
				else if(x == '"' || x == '\'' || (x == '[' && inlua[i+1] == '[') )
				{
					char exitnode = x;
					if(x == '[')
					{
						exitnode = ']';
						i++;
						outlua+= "[[";
					}
					else outlua += x;
					
					i++;
					if(x == ']') i++;
					
					while(i < inlua.length())
					{
						char y = inlua[i];
						
						if(y == '\\')
						{
							outlua += y;
							outlua += inlua[i+1];
							i += 2;
							continue;
						}
						
						outlua += y;
						i++;
						
						if(y == exitnode)
						{
							if(y == ']')
							{
								outlua += "]";
								i++;
							}
							break;
						}
					}
				}
				else if(x == '-' && inlua[i+1] == '-' && i < inlua.length() - 1) // -1 on len to prevent crash if file ends with "-"
				{
					// comments
					outlua += "--";
					i+= 2;
					while(i < inlua.length())
					{
						char y = inlua[i];
						outlua += y;
						
						if(y == '\n' || y == '\r')
							break;
						
						i++;
					}
				}
				else
				{
					outlua += x;
					i++;
				}
			}
		}
		
	}
	
	outlua += "]])";
	
	lua_pushstring(L, outlua.c_str());
	
	return 1;
}

