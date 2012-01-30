#include <iostream>
#include <stdio.h>
#include <string>
#include <sstream>
#include <cstring>

// microhttpd
#include <microhttpd.h>

// Some stuff to display the IP
#include <sys/socket.h>
#include <net/route.h>
#include <net/if.h>
#include <netinet/in.h>
#include <arpa/inet.h>

#include "LuaFuncs.h"
#include "HandelConnection.h"

#include <unordered_map>

using namespace std;

CConnectionHandler ch;

int Port;

int Connection(void *cls, struct MHD_Connection *connection, const char *url, const char *method, const char *version, const char *upload_data, size_t *upload_data_size, void **con_cls)
{
	connection_t con;
	con.method = method;
	con.url = url;
	con.version = version;
	
	con.response = "";
	con.errcode = MHD_HTTP_OK;
	
	struct sockaddr *so;
	so = MHD_get_connection_info(connection, MHD_CONNECTION_INFO_CLIENT_ADDRESS)->client_addr;
	con.ip = inet_ntoa( ((sockaddr_in*)so)->sin_addr );
		
	todo_t todo;
	todo.FileDataInstead = 0;
	// Now we setup our struct, we can pass it to the handeler
	
	try
	{
		ch.Handel(&con, connection, todo);
	}
	catch(...)
	{
		printf("Exception happend\n");
	}
	
	const char *page  = con.response.c_str();
	
	struct MHD_Response* response;
	
	if(todo.FileDataInstead)
	{
		response = MHD_create_response_from_buffer (todo.FileDataLength, (void*)todo.FileDataInstead, MHD_RESPMEM_MUST_COPY);
		delete [] todo.FileDataInstead; // How does this know the size of the array?
	}
	else
		response = MHD_create_response_from_buffer (strlen (page), (void*)page, MHD_RESPMEM_MUST_COPY);
	
	for(auto it = todo.response_headers.begin(); it != todo.response_headers.end(); it++)
		MHD_add_response_header(response, it->first.c_str(), it->second.c_str());
	
	for(auto it = todo.set_cookies.begin(); it != todo.set_cookies.end(); it++)
	{
		string cookie = it->first + "=" + it->second;
		MHD_add_response_header(response, "Set-Cookie", cookie.c_str());
	}
	
	int ret = MHD_queue_response (connection, con.errcode, response);
	MHD_destroy_response (response);

	return ret;
}

int main (int argc, char* argv[])
{
	printf("Loading luaserver... ");
	
	if(argc > 3 || argc < 2)
	{
		Port = 8081;
		//return 1;
	}
	else
	{
		string sport = argv[1];
		istringstream ( sport ) >> Port;
	}
	
	//MHD_USE_SELECT_INTERNALLY
	struct MHD_Daemon *daemon = MHD_start_daemon(MHD_USE_SELECT_INTERNALLY | MHD_USE_THREAD_PER_CONNECTION, Port, NULL, NULL, &Connection, NULL, 
		MHD_OPTION_PER_IP_CONNECTION_LIMIT, 	(unsigned int)4,
		MHD_OPTION_CONNECTION_LIMIT, 			(unsigned int)40,
		MHD_OPTION_CONNECTION_TIMEOUT, 			(unsigned int)10,
	MHD_OPTION_END);
		
	if(!daemon)
	{
		printf("\t [Fail]\nPlease check nothing else is using the same port!\n");
		return 1;
	}
	
	printf("\t [OK]\n");
	
	while(true)
	{
		usleep(100000); // 10ms
		PrecacheLuaStates();
	}

	MHD_stop_daemon (daemon);
	return 0;
}

	
	
	
