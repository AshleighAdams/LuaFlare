#pragma once
#ifndef HANDEL_CON_H
#define HANDEL_CON_H

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
	void Handel(ServerConnection* pConnection);
protected:
};

#endif // HANDEL_CON_H
