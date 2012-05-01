#include <iostream>
#include <stdio.h>
#include <string>
#include <sstream>
#include <cstring>

// microhttpd
#include <microhttpd.h>

// Some stuff to display the IP
//#include <sys/socket.h>
//#include <net/route.h>
//#include <net/if.h>
//#include <netinet/in.h>
//#include <arpa/inet.h>

#include <iostream>

#include "LuaFuncs.h"
#include "HandelConnection.h"

#include <unordered_map>

#include "LuaServerInterface.h"

#if defined _WIN32 || defined _WIN64
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#endif

using namespace std;

CConnectionHandler ch;

typedef ILuaServerInterface*(*FnGetInterface)(void);

ILuaServerInterface* GetInterface()
{
	FnGetInterface pGetInterface = 0;
	
#if defined _WIN32 || defined _WIN64
	HMODULE hand = LoadLibrary("luaserver-interface-default.dll");
	if(!hand)
	{
		cout << "Could not load `luaserver-interface-default.dll'\n";
		return 0;
	}
	pGetInterface = (FnGetInterface)GetProcAddress(hand, "GetInterface");
	if(!pGetInterface)
	{
		cout << "Could not find export `GetInterface' from `luaserver-interface-default.dll'\n";
		return 0;
	}
#else
	cout << "Not yet implemented for Linux\n";
	return 0;
#endif
	return pGetInterface();
}

#include "boost/filesystem/operations.hpp"
#include "boost/filesystem/path.hpp"
#include <iostream>
#include <sstream>

int main (int argc, char* argv[])
{
	{
		string inpath = string(argv[0]) + "/../../";
		boost::filesystem::path full_path( boost::filesystem::initial_path<boost::filesystem::path>() );
		full_path = boost::filesystem::system_complete( boost::filesystem::path( inpath ) );
		
		stringstream ss;
		ss << full_path;
		
		string tmp = ss.str();
		tmp = tmp.substr(1, tmp.length() - 2);
		const char* g_pWorkingDIR = tmp.c_str();
#if defined _WIN32 || defined _WIN64
		SetCurrentDirectory(g_pWorkingDIR);
#else
#endif
		
	}
	    
	printf("Loading luaserver... ");
	
	unsigned long Port;
	if(argc > 3 || argc < 2)
		Port = 8081;
	else
	{
		string sport = argv[1];
		istringstream ( sport ) >> Port;
	}
	
	ILuaServerInterface* pInterface = GetInterface();
	
	FnNewConnection pNewConnection = [&](ServerConnection* pConnection)
	{
		ch.Handel(pConnection);
	};
	
	if(!pInterface)
	{
		printf("\t [Fail]\nFailed to get interface!\n");
		return 1;
	}
	
	pInterface->SetCallback(pNewConnection);
	
	if(!pInterface->Init(Port))
	{
		printf("\t [Fail]\nPlease check nothing else is using the same port!\n");
		return 1;
	}

	printf("\t (%s) [OK]\n", pInterface->GetInterfaceName());

	while(true)
	{
		usleep(10000); // 1ms, 1000 precaches per second * (PRECACHE_SIZE (16))
		PrecacheLuaStates();
	}
	return 0;
}




