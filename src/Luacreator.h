#pragma once
#ifndef LUACREATOR_H
#define LUACREATOR_H

#include "LuaServerInterface.h"

#include "LuaFuncs.h"
#include <functional>

#define PRECACHE // Comment out this line if you do NOT want to precache (slower, but uses less memory)
#define PRECACHE_SIZE 32

class LuaCreator
{
public:
	LuaCreator();
	~LuaCreator();
	lua_State* GetState();
	const char* GetStringFromTable(const char* key);
	double GetNumberFromTable(std::string key);
	bool TrySetup(ServerConnection* pConnection);
	void ItterateTable(std::function<void(std::string k, std::string v)> callback);
	
protected:
	lua_State* m_L;
	bool m_Failed;
};

extern void PrecacheLuaStates();

#endif // LUACREATOR_H
