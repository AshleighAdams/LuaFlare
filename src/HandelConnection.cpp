#include "HandelConnection.h"
#include <functional>
#include <iostream>
#include <fstream>

#include "LuaServerInterface.h"

using namespace std;

CConnectionHandler::CConnectionHandler()
{
	
}
CConnectionHandler::~CConnectionHandler()
{
}


inline void AddToTable(lua_State* L, const char* Name, string Key, string Value)
{
	lua_pushstring(L, Name); 				// Push the string
	lua_gettable(L, -2);					// Get the table the corrosponds to it, and put it on the stack
		lua_pushstring(L, Key.c_str());		// Push key and value to the stack
		lua_pushstring(L, Value.c_str());
		lua_rawset(L, -3);					// Tell lua to add them to the table
	lua_pop(L, 1); 							// I don't recall which this pops (table or string(type)); it's one of them...
}

void CConnectionHandler::Handel(ServerConnection* pConnection)
{
	LuaCreator LC;
	
	if(!LC.TrySetup(pConnection))
	{
		pConnection->ErrorCode = 501;
		return;
	}
	
	lua_State* L = LC.GetState();
	
	for(auto it = pConnection->Headers.begin(); it != pConnection->Headers.end(); it++)
		AddToTable(L, "HEADER", it->first, it->second);
		
	for(auto it = pConnection->GETParams.begin(); it != pConnection->GETParams.end(); it++)
		AddToTable(L, "GET", it->first, it->second);
	
	for(auto it = pConnection->POSTParams.begin(); it != pConnection->POSTParams.end(); it++)
		AddToTable(L, "POST", it->first, it->second);
	
	for(auto it = pConnection->Cookies.begin(); it != pConnection->Cookies.end(); it++)
		AddToTable(L, "COOKIE", it->first, it->second);
	
	// 1 argument, 1 result
	// The lock is removed so that many threads can run at the same time.
	if (lua_pcall(L, 1, 1, 0)) 
	{
		printf("error running function `main': %s\n", lua_tostring(L, -1));
		
		const char* reason = "Lua error!";
		
		size_t len = strlen(reason);
		
		pConnection->DataLength = len;
		pConnection->pData = new unsigned char[len];
		memcpy(pConnection->pData, reason, len);
		
		pConnection->ErrorCode = 501;
		return;
	}
	else
	{
		const char* resp = LC.GetStringFromTable("response");
		unsigned int strlength = strlen(resp);
		
		//pConnection->pData = (unsigned char*)resp;		
		//pConnection->DataLength = strlength;
		//pConnection->DataIsConstant = true;
		
		pConnection->pData = new unsigned char[strlength];		
		pConnection->DataLength = strlength;
		pConnection->DataIsConstant = false;
		
		// Copy the data to our new string (the lua one is not garrunteed to be in memory
		memcpy(pConnection->pData, resp, strlength);
		
		// TODO: Clean this bit up
		lua_pushstring(L, "response_file");
		{
			lua_gettable(L, -2);

			if(lua_isstring(L, -1))
			{
				const char* filename = lua_tostring(L, -1);
				
				ifstream ifs(filename, ios::binary);
				
				if(ifs.is_open())
				{
					ifs.seekg(0, ios::end);
					unsigned int filesize = ifs.tellg();
					ifs.seekg(0, ios::beg);

					char* contents = new char[filesize];
					ifs.read(contents, filesize);
					
					ifs.close();
					
					pConnection->pData = (unsigned char*)contents;
					pConnection->DataLength = filesize;
					pConnection->DataIsConstant = false;
					
					pConnection->ErrorCode = 200;
				}else{
					pConnection->ErrorCode = 404; // con.errcode will overide this, so if you want it to use this, set it to nil
				}
			}
			
		}
		lua_pop(L, 1); // "response_file"
		
		pConnection->ErrorCode = (unsigned int)LC.GetNumberFromTable("errcode");
		
		lua_pushstring(L, "response_headers");
		{
			LC.ItterateTable([&](string k, string v)
			{
				pConnection->ResponseHeaders[k] = v;
				//pConnection->ResponseHeaders.insert(ResponseHeadersMap::value_type(k, v));
			});
		}
		lua_pop(L, 1); // "response_headers"
		
		
		lua_pushstring(L, "set_cookies");
		{
			LC.ItterateTable([&](string k, string v)
			{
				std::cout << "Sending cookie " << k << " = " << v << "\n";
				pConnection->SetCookies[k] = v;
			});
		}
		lua_pop(L, 1); // "set_cookies"
	}
	
	lua_pop(L, 1); // The retun table
	
	int stackpos = lua_gettop(L);
	if(stackpos)
		printf("WARNING: stack not at 0 (%i)\n", stackpos);
}
