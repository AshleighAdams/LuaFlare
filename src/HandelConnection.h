#pragma once
#ifndef HANDEL_CON_H
#define HANDEL_CON_H

extern "C" {
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
}

#include "LuaFuncs.h"

#include <unordered_map>

typedef std::unordered_map<std::string, std::string> ResponseHeadersMap;

struct todo_t
{
	ResponseHeadersMap response_headers;
	ResponseHeadersMap set_cookies;
	char* FileDataInstead;
	int FileDataLength;
};


class CConnectionHandler
{
public:
	CConnectionHandler();
	~CConnectionHandler();
	void Handel(connection_t* connection, MHD_Connection* mhdcon, todo_t& todo);
	
	bool Failed;
protected:
	lua_State* l;
};

#endif // HANDEL_CON_H
