# Internal Workings

	main_loop()
		safehook ReloadScripts
		hook Loaded
		while true:
			if threadpool_isdone:
				wait til the next scheduled task is to be ran
			else:
				wait forever for a client
			
			safehook ReloadScripts
			
			handle_client(client) -- returning true = keep connection open
				Response(client)
				safehook Request(req, res)
					default: hosts.process_request
						if hosts.upgrade_request(): return -- ie, websockets
						host = hosts.match(req:hosts())
						if not host: generate conflict page
						page = host:match
						if 404: try the same, but with hosts.any if host.options.no_fallback is not truthy.
						if still not page: show error
						
						page.callback(req, res, args...)
			if handle_client did not return true:
				client:close()
			
			run an interation of the scheduler
		
