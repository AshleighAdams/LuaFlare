# Internal Workings

## Entry point

The entry point of `main_loop` is responsible for loading all the autorun scripts safely via the hook `ReloadScripts`,
once all the autorun files are loaded, the hook `Load` is unsafely called.
The `Load` hook is responsible for parsing things such as (in order):

 - Parse reverse proxies, mime types, etc...
 - Notify the daemon manager by outputting the PID (`--out-pid=file`), or reporting to systemd (`--systemd`).

Once loaded, `main_loop` will enter an infinite loop.
The infinite loop works by first attempting to accept a TCP client.
If there is clients still connected/in the queue (thread pool), then the accept function will not attempt to wait;
however if there are no active connections, then accept will attempt to wait until the next scheduled task is ready to run.
Before enqueueing the client, if `--no-reload` is not set, then any autorun scripts (`/lua/ar_*.lua`) that have changed (or are new) will be re-executed.

Now the client will be enqueued, the thread-pool ran which processes the connections, and then finally the scheduler will resume.

## Processing the connection

The thread pool responsible for processing the connections will call `handle_client(client)`,
where it will attempt to construct a `Request` object, and keep trying until it either the connection is closed, the Request constructor fails (and returns `nil, errstr`), the connection has been upgraded, or the keep-alive timeout is reached.

Once the request and response objects have been constructed, the hook `Request` is safely called.
By default, the `Request` hook is processed by `hosts.process_request`.

The first thing `hosts.process_request()` will attempt is to upgrade the connection (check [Upgrading](#upgrading) for further detail).
If the request does not want to be upgraded, then LuaFlare will attempt to locate a host for the request via pattern matching against all hosts, falling back to `hosts.any` if none is found;
if we find more than one host that can take said request, then a `500 Internal Server Error` response is sent.

Now that a valid host object has been obtained, LuaFlare will attempt to locate a page that matches the request's resource.
During page matching, a list of valid methods (GET, POST, ...), then eliminated from the matches if it wasn't suitable for this request;
if all pages have been eliminated and one or more other methods could have feasibly handled the request for this resource, then a `405 Method Not Allowed` is sent, along with the `Allow` header being filled out with the aforementioned valid methods list
([RFC2616 &sect; 10.4.6](http://www.w3.org/Protocols/rfc2616/rfc2616-sec10.html#sec10.4.6) and [RFC7231 &sect; 6.5.5](http://tools.ietf.org/html/rfc7231#section-6.5.5))
If the match failed because of a `404 Not Found` and `options.no_fallback` is falsy, then an attempt to match against `host.any` is made.

If a page has still not been found, then `halt()` is called with the error code and error reason (i.e., a conflict between pages, or a 404);
otherwise the page callback will be invoked with the arguments `request, response, ...`, where `...` is either, the captures from the page pattern, or the whole URL (no captures).

## Upgrading

To test whether or not a request wants it's connection to be upgraded,
the header `Connection` is checked to see if `upgrade` is present,
and then the `Upgrade` header is checked to exist.
If both of these are true, then an attempt to upgrade the connection is made by checking the that `hosts.upgrades[x]` exists, where `x` is the value of the `Upgrade` header.
In the case of the upgrade function not being found, then LuaFlare will respond to the request with a `404 Not Found` with the message "Upgrade not found" and return.

Now that we have our function that is responsible for upgrading the request (upgrader), it will be invoked.
The upgrader is responsible for calling `request:set_upgraded()`;
this ensures that both, the connection is not closed, and no more requests are attempted to be read from this connection.

## Pseudocode

	main_loop():
		safehook ReloadScripts
		hook Load
		while true:
			if threadpool_isdone:
				wait til the next scheduled task is to be ran
			else:
				no waiting, pop one if there, but do not wait
			
			safehook ReloadScripts
			
			handle_client(client): -- returning true = keep connection open
				Response(client)
				safehook Request(req, res):
					default: hosts.process_request
						if hosts.upgrade_request(): return -- ie, websockets
						host = hosts.match(req:hosts())
						if not host: generate conflict page
						page = host:match(url, method):
							test static and patterns registered against url
							test against HTTP methods
							check for conflicts
						if 404: try the same, but with hosts.any if host.options.no_fallback is not truthy.
						if still not page: show error
						
						page.callback(req, res, args...)
				return client:is upgraded() or keepalive -- keep the connection alive if we upgraded or keepalived
			if handle_client did not return true:
				client:close()
			
			run an interation of the scheduler
	
	upgrade_request():
		if not connection has upgrade part: return false
		get upgrade func from Connection header
		if not upgrade func:
			halt("invalid upgrade")
		else:
			upgrade_func(req, res)
				upgrade_func is responsible for setting
				is_upgraded, to prevent the connection from
				being closed
		return true

