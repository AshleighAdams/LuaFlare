#pragma once
#ifndef LUACREATOR_H
#define LUACREATOR_H

#include "LuaFuncs.h"
#include <functional>

struct todo_t; // Forward declerations
struct connection_t;

class LuaCreator
{
public:
	LuaCreator();
	~LuaCreator();
	lua_State* GetState();
	std::string GetStringFromTable(std::string key);
	double GetNumberFromTable(std::string key);
	bool TrySetup(connection_t* connection, MHD_Connection* mhdcon, todo_t& todo);
	void ItterateTable(std::function<void(std::string k, std::string v)> callback);
protected:
	lua_State* m_L;
};


#endif // LUACREATOR_H
