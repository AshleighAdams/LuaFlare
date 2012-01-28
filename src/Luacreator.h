#pragma once
#ifndef LUACREATOR_H
#define LUACREATOR_H

#include "LuaFuncs.h"

struct todo_t; // Forward declerations
struct connection_t;

class LuaCreator
{
public:
	LuaCreator();
	~LuaCreator();
	lua_State* GetState();
	bool TrySetup(connection_t* connection, MHD_Connection* mhdcon, todo_t& todo);
protected:
	lua_State* m_L;
};


#endif // LUACREATOR_H
