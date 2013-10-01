LuaServer
=========

# Documentation

The files that match the pattern lua/*/ar_*.lua will be automatically ran at the start, and when they're modified. Use
`include(file)` to include files relative to your directory, and to specify files that your script depends on, so that
they may be automatically reloaded too.

## Basic functions
```lua
reqs.AddPattern(host, url_pattern, callback --[[request, response, ...]])
reqs.AddPattern("*", "/hello_world", hello_world)
reqs.AddPattern("host.com", "/hello_host", hello_host)
reqs.AddPattern("*", "user/%d+/message", send_message)

--AddPattern also appends any captures to the function's arguments:
reqs.AddPattern("*", "user/%d+/message", function(req, res, id)
	print("sending message to ", id)
end)
```

## Overriding default handler

The following code will remove the hook used by reqs, so you can impliment your own if you desire
```lua
hook.Remove("Request", "default")
hook.Add("Request", "mine", function(req, res)
	-- ...
end)
```

# Behind Nginx

It is recommended that you run LuaServer behind Nginx to prevent many types of attacks, and other things
provided by Nginx, such as compression.

Example Nginx config:
```
server {
	listen 80 default_server;
	listen [::]:80 default_server ipv6only=on;

	server_name localhost;

	location / {
		proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
		proxy_set_header Host $http_host;
		proxy_pass http://localhost:8080;
	}
}
```
