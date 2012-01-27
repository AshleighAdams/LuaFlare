#include "LuaFuncs.h"
#include <stdio.h>
#include <sys/stat.h>
#include <string>
#include <sstream>
#include <iostream>

#include <dirent.h>
#include <time.h>
using namespace std;

// For the session string
#include <random>

#ifdef WINDOWS // We need a standard for this...
/*
	Thanks to Carl Staelin for this snippet
	http://stackoverflow.com/questions/5404277/porting-clock-gettime-to-windows
*/
#define CLOCKS_PER_SEC 0
LARGE_INTEGER getFILETIMEoffset()
{
	SYSTEMTIME s;
	FILETIME f;
	LARGE_INTEGER t;

	s.wYear = 1970;
	s.wMonth = 1;
	s.wDay = 1;
	s.wHour = 0;
	s.wMinute = 0;
	s.wSecond = 0;
	s.wMilliseconds = 0;
	SystemTimeToFileTime( &s, &f );
	t.QuadPart = f.dwHighDateTime;
	t.QuadPart <<= 32;
	t.QuadPart |= f.dwLowDateTime;
	return t;
}

int ::clock_gettime( int X, struct timeval* tv )
{
	LARGE_INTEGER		   t;
	FILETIME				f;
	double				  microseconds;
	static LARGE_INTEGER	offset;
	static double		   frequencyToMicroseconds;
	static int			  initialized = 0;
	static BOOL			 usePerformanceCounter = 0;

	if ( !initialized )
	{
		LARGE_INTEGER performanceFrequency;
		initialized = 1;
		usePerformanceCounter = QueryPerformanceFrequency( &performanceFrequency );
		if ( usePerformanceCounter )
		{
			QueryPerformanceCounter( &offset );
			frequencyToMicroseconds = ( double )performanceFrequency.QuadPart / 1000000.;
		}
		else
		{
			offset = getFILETIMEoffset();
			frequencyToMicroseconds = 10.;
		}
	}
	if ( usePerformanceCounter )
		QueryPerformanceCounter( &t );
	else
	{
		GetSystemTimeAsFileTime( &f );
		t.QuadPart = f.dwHighDateTime;
		t.QuadPart <<= 32;
		t.QuadPart |= f.dwLowDateTime;
	}

	t.QuadPart -= offset.QuadPart;
	microseconds = ( double )t.QuadPart / frequencyToMicroseconds;
	t.QuadPart = microseconds;
	tv->tv_sec = t.QuadPart / 1000000;
	tv->tv_usec = t.QuadPart % 1000000;
	return 0;
}
#endif // WINDOWS

int l_GetCurrentTime(lua_State* L)
{

	
	struct timespec now;
	clock_gettime( CLOCK_MONOTONIC, &now );

	double dbl = (( double )( now.tv_nsec / CLOCKS_PER_SEC ) / 1000.0 + ( double )now.tv_sec);
	
	lua_pushnumber(L, dbl);
	return 1;
}

double GetCurrentTime()
{
	struct timespec now;
	clock_gettime( CLOCK_MONOTONIC, &now );

	return (( double )( now.tv_nsec / CLOCKS_PER_SEC ) / 1000.0 + ( double )now.tv_sec);
}

unsigned long GetMicroTime()
{
	struct timeval tv;
	gettimeofday(&tv,NULL);
	return 1000000*(tv.tv_sec)+(tv.tv_usec);
}

unsigned long From = 0;

int l_ResetMicroTime(lua_State* L)
{

	
	From = GetMicroTime();
	return 0;
}

int l_MicroTime(lua_State* L)
{

	
	lua_pushnumber(L, (double)(GetMicroTime() - From));
	return 1;
}

void LoadMods(lua_State* L, string sdir)
{

	
	DIR *dir;
	struct dirent *ent;
	dir = opendir (sdir.c_str());
	if (dir != NULL)
	{
		while ((ent = readdir (dir)) != NULL)
		{
			if(ent->d_type == DT_DIR)
			{
				if(string(ent->d_name) == "..") continue;
				if(string(ent->d_name) == ".") continue;
				string newdir = sdir + ent->d_name + "/";
				
				LoadMods(L, newdir);
			}
			else
			{
				string lfile = sdir + ent->d_name;
				printf ("Loading %s\n", lfile.c_str());
				
			}
		}
		closedir (dir);
	}
}

void LoadMods(lua_State* L)
{
	LoadMods(L, "mods/");
}

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
			case '&':	buf.append("&amp;");		break;
			case '\"':	buf.append("&quot;");	break;
			case '\'':	buf.append("&apos;");	break;
			case '<':	buf.append("&lt;");		break;
			case '>':	buf.append("&gt;");		break;

			default:	buf.append(1, in[pos]);	break;
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
/*
This function basically turns:

Hello, <b><?lua write(GET.NAME or Unknown)?></b>.

Into:

write(false, [[Hello, <b>]])write(GET.NAME or Unknown)write(false,[[</b>.]])

It must not break under comments, strings or any other conditions like:

	-- Hello, ?>/<?lua world.
	func("Hello, ?>/<?lua world")
	func('Hello, ?>/<?lua world')
	func([[Hello, ?>/<?lua world]])
	
Escaping must work too:
	
	func("Just testing \") something")
	And this must work too:
	
	lua = [[ This is a test \]]
*/
int l_ParseLuaString(lua_State* L)
{

	
	string inlua = luaL_checkstring(L, 1);
	string outlua;
	
	outlua.reserve(inlua.size());

	int parsemode = PARSEMODE_OUTOFLUA;
	unsigned int inluastart = 0;
	outlua += "write(false,[[";
	
	unsigned int i = 0;
	
	while(i < inlua.length())
	{
		if(parsemode == PARSEMODE_OUTOFLUA)
		{
			while(i < inlua.length())
			{
				char x = inlua[i];
				if((i < inlua.length() - 4) && x == '<' && inlua[i+1] == '?' && inlua[i+2] == 'l' && inlua[i+3] == 'u' && inlua[i+4] == 'a')
				{
					inluastart = i;
					i += 5;
					outlua += "]])";
					parsemode = PARSEMODE_INLUA;
					break; // New parse mode!
				}
				else if(x == ']') 	// Major bloody hack D:
				{					// No other way, you can't put a ] in a literal string
					if(inlua[i+1] == ']')
					{
						outlua += "]] .. \"]]\" .. [[";
						i += 2;
					}
					else
					{
						outlua += "]] .. \"]\" .. [[";
						i += 1;
					}
				}
				else if(x == '[')
				{
					if(inlua[i+1] == '[')
					{
						outlua += "]] .. \"[[\" .. [[";
						i += 2;
					}
					else
					{
						outlua += "]] .. \"[\" .. [[";
						i += 1;
					}
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
						
						if(y == '\\' && exitnode != ']') // Escape the next char, but only if we're not in a literal string
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
								if(inlua[i] != ']')
									continue;
								outlua += "]\n";
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
					
					bool multiline = false;
					
					if(inlua[i] == '[' && inlua[i+1] == '[' )
					{
						outlua += "[[";
						i+= 2;
						multiline = true;
					}
					
					while(i < inlua.length())
					{
						char y = inlua[i];
						outlua += y;
						
						if(!multiline && (y == '\n' || y == '\r'))
							break;
							
						if(multiline && y == ']' && inlua[i + 1] == ']')
						{
							outlua += "]";
							i+=2;
							break;
						}
						
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
	
	if(parsemode == PARSEMODE_INLUA)
	{
		string offendingline = "";
		int linecount = 1;
		
		for(i = 0; i < inluastart; i++)
		{
			char x = inlua[i];
			if(x == '\r' && inlua[i+1] == '\n' && i < inluastart - 1)
			{
				linecount++;
				i++;
			}
			else if(x == '\r')
				linecount++;
			else if(x == '\n')
				linecount++;
		}
		
		while(i < inlua.length())
		{
			char x = inlua[i];
			if(x == '\n' || x == '\r')
				break;
			i++;
			offendingline += x;
		}
		// now we have the line number and line
		
		stringstream ss;
		ss << linecount;
		
		string error = "'?>' expected near '" + offendingline + "' (line " + ss.str() + ")";
		
		lua_pushnil(L);
		lua_pushstring(L, error.c_str());
		return 2;
	}
	
	lua_pushstring(L, outlua.c_str());
	return 1;
}

unsigned long* g_RandSeedOffset = 0;
int g_LastRand;

#define RENEW_SEED() \
	*g_RandSeedOffset+= g_LastRand; \
	engine.seed((unsigned long)g_RandSeedOffset + GetMicroTime() + *g_RandSeedOffset)

int l_GenerateSessionID(lua_State* L)
{

	
	if(!g_RandSeedOffset)
		g_RandSeedOffset = new unsigned long;
	
	int len = (int)luaL_checkint(L, 1);
	
	char* res = new char[len+1];
	res[len] = '\0';
	
	uniform_int_distribution<int> distro(0, 255);
	uniform_int_distribution<int> switch_distro(0, 2); // 0 = number, 1 = lowercase, 2 = upper case
	
	mt19937 engine;
	
	RENEW_SEED();
	
	int rand;
	
	for(int i = 0; i < len; i++)
	{
		RENEW_SEED();
		rand = distro(engine);
		g_LastRand += rand;
		
		switch(switch_distro(engine))
		{
		case 0:
			rand = 48 + (rand % 10);
		break;
		case 1:
			rand = 97 + (rand % 26);
		break;
		case 2:
			rand = 65 + (rand % 26);
		break;
		}
		
		res[i] = (char)rand;
	}
	
	lua_pushstring(L, res);
	return 1;
}

int LockCount = 0;

LuaAPILock::LuaAPILock()
{
	int mine = LockCount;
	LockCount++;
	
	while(LockCount > mine && LockCount != 1) // If it's one, we are the only ones waiting
		;
}

LuaAPILock::~LuaAPILock()
{
	LockCount--;
}
