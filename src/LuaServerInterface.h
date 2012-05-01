
#ifndef LUA_SERVER_INTERFACE_H
#define LUA_SERVER_INTERFACE_H

// Some STL libaries we need.
#include <functional>
#include <list>
#include <string>
#include <unordered_map>

// Forward decleration
struct ServerConnection;

// Some typedefs to make things easier
typedef std::unordered_map<std::string, std::string> MapHeaders;
typedef std::unordered_map<std::string, std::string> MapS2S;
typedef std::function<void(ServerConnection* pConnection)> FnNewConnection;

// Here is what needs to be implemented.

struct ServerConnection
{
	std::string 		IP;
	std::string 		Method;
	std::string			RequestedFile;
	std::string			VersionString;
	MapS2S				Cookies;
	MapS2S				SetCookies;
	MapS2S 				Headers;
	MapS2S				GETParams;
	MapS2S				POSTParams;
	MapS2S		 		ResponseHeaders;
	unsigned int 		ErrorCode;
	unsigned char*		pData;
	unsigned int		DataLength;
	bool				DataIsConstant;
};


class ILuaServerInterface
{
public:
	virtual ~ILuaServerInterface(){}
	virtual bool Init(unsigned int Port) = 0;
	virtual bool SetCallback(FnNewConnection Callback) = 0;
	virtual const char* GetInterfaceName() = 0;
};


#endif // LUA_SERVER_INTERFACE_H
