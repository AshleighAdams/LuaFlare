# LuaFlare hosts library

`local hosts = require("luaflare.hosts")`

## `hosts.any`

The fallback (wildcard) site.

## `hosts.developer`

The developers site.  It is recommended you disable this in a production enviroment.

## `hosts.method_synoms`

A table in the form of:

	{
		METHOD = {
			SYNONYMOUS_METHOD = true,
			...
		},
		...
	}

## `host hosts.get(string pattern[, table options])`

Returns a host with the input pattern.  If it does not already exist, then it will be created, and it's options set.

- The argument `pattern` is in the form:
	- `"*.xyz.tld"`: subdomains and root domain of "xyz.tld".
		- `xyz.tld`
		- `a.xyz.tld`
		- `b.a.xyz.tld`
	- `"~.xyz.tld"`: subdomains only of "xyz.tld".
		- `a.xyz.tld`
		- `b.a.xyz.tld`
	- `"+.xyz.tld"`: 2<sup>nd</sup> level subdomains only of "xyz.tld"
	 	- `a.xyz.tld`
- `options`: A table of host options.
	- `no_fallback`: Don't fall back to `hosts.any` if a page could not be matched.
- returns: The host.

## `host[, err] hosts.match(string host)`

Gets the host that matches `host`.

- `host`: The host to test against.
- returns: Either the matched host, or nil plus an error string.

## *`hosts.process_request(request, response)`*

Finds the correct host and page, and invokes it.  Will handle HTTP upgrades too.

## *`hosts.upgrade_request(request, response)`*

Checks to see if this request should be upgraded.

- returns: true if it has eaten the request, else false.

## `host:addpattern(string pattern, function callback, string method = "GET")`

Add a route that matches `pattern`.  Captures from the pattern are passed to callback after the request and response objects.

- `pattern`: The URL pattern.
- `callback`: The function; should be in the format `function(request, response, ...)` where `...` are the captures from `pattern`.
- `method`: The HTTP method that should be used.

### Example

    local function hello(req, res, msg)
    	res:append(msg)
    end
    hosts.any:addpattern("/hello/(.+)", hello)

## `host:add(string url, function callback, string method = "GET")`

Adds a direct link to a function, no pattern matching is done.

- `url`: The URL to add.
- `callback`: The function; should be in the format `function(request, response, url)`.
- `method`: The HTTP method that should be used.

## `page, args[, errcode[, errstr[, headers]]] host:match(string url, string method = "GET")`

- `url`: The URL to test against.
- `method`: The method to test against.
- returns:
	- `page`: The page table.  Is nil on error.
	- `args`: The array of arguments to pass to `page.callback`.  Is nil on error.
	- `errcode`: The HTTP error code to send.
	- `errstr`: The reason for the error.
	- `headers`: A table of additional headers to set.
