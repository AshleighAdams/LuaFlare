#pragma once
#ifndef HANDEL_CON_H
#define HANDEL_CON_H

extern "C" {
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}

#include "LuaFuncs.h"

class CConnectionHandler
{
public:
	CConnectionHandler();
	~CConnectionHandler();
	void Handel(connection_t* connection, MHD_Connection* mhdcon);
	
	bool Failed;
protected:
	lua_State* l;
};

#endif // HANDEL_CON_H
