#include <iostream>
#include <stdio.h>
#include <string>
#include <cstring>

// microhttpd
#include <microhttpd.h>

// LuaBind
#include "luabind/luabind.hpp"

using namespace std;


int Connection(void *cls, struct MHD_Connection *connection, const char *url, const char *method, const char *version, const char *upload_data, size_t *upload_data_size, void **con_cls)
{
	const char *page  = "<html><body>Hello, browser!</body></html>";

	struct MHD_Response* response = MHD_create_response_from_buffer (strlen (page), (void*) page, MHD_RESPMEM_MUST_COPY);

	int ret = MHD_queue_response (connection, MHD_HTTP_OK, response);
	MHD_destroy_response (response);

	return ret;
}


int main ()
{
	printf("Loading luaserver... ");
	
	struct MHD_Daemon *daemon = MHD_start_daemon (MHD_USE_SELECT_INTERNALLY, 8080, NULL, NULL, &Connection, NULL, MHD_OPTION_END);
		
	if(!daemon)
	{
		printf("\t [Fail]\n");
		return 1;
	}
	
	printf("\t [OK]\n");
	
	while(true)
	{
		getchar();
	}

	MHD_stop_daemon (daemon);
	return 0;
}

	
	
	
