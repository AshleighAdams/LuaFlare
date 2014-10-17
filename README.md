LuaServer [![Build Status](http://kateadams.eu/build/LuaServer/master/state.png)](http://kateadams.eu/build/LuaServer/master/)
=========

# Table of Contents

- [1. Documentation](#documentation)  
	- [1.1. Command Line Arguments](#command-line-arguments)  
	- [1.2. Handle a Page](#handle-a-page)  
	- [1.3. Templating System](#templating-system)  
		- [1.3.1. Escaping](#escaping)  
		- [1.3.2. Examples](#examples)  
			- [1.3.2.1. Example 1 - Simple](#example-1---simple)  
			- [1.3.2.1. Example 2 - Basic Page](#example-2---basic-page)  
			- [1.3.2.1. Example 3 - Segmants](#example-3---segmants)  
			- [1.3.2.1. Example 4 - Unpack](#example-4---unpack)  
	- [1.4. Overiding Default Handler](#overiding-default-handler)  
- [2. Behind Nginx](#behind-nginx)  
	- [2.1. HTTP](#http)  
	- [2.2. HTTPS](#https)  
- [3. To Do](#to-do)  
- [4. Functions Provided](#functions-provided)  
	- [4.1. util](#util)  
	- [4.2. table](#table)  
	- [4.3. string](#string)  
	- [4.4. math](#math)  
	- [4.5. escape](#escape)  
	- [4.6. os](#os)  
	- [4.7. script](#script)  
	- [4.8. stack](#stack)  
	
# Documentation

The files that match the pattern lua/\*/ar_\*.lua will be automatically ran at the start, and when they're modified. Use
`include(file)` to include files relative to your directory, and to specify files that your script depends on, so that
they may be automatically reloaded too.

## Command Line Arguments

| Command                              | Default Value | Allowed Values          | Info                                                      |
| ------------------------------------ | ------------- | ----------------------- | --------------------------------------------------------- |
| --config=\<path\>                    |               | \*                      | Load and save arguments to this file.                     |
| --port=\<number\>                    | 8080          | 0-65535                 | Set the port to run on.                                   |
| --threads=\<number\>                 | 2             | 0-\*                    | How many threads to create.                               |
| --threads-model=\<string\>           | coroutine     | coroutine, pyrate       | How will Lua create the threads?                          |
| --host=\<string\>                    | \*            | \*                      | Bind to this address.                                     |
| -l, --local                          | false         | true, false             | Set the host to "localhost".                              |
| -t, --unit-test                      | false         | true, false             | Perform unit tests and quit.                              |
| -h, --help                           | false         | true, false             | Show the help information then quit.                      |
| -v, --version                        | false         | true, false             | Show the version information then quit.                   |
| --no-reload                          | false         | true, false             | Do not automatically reload scripts.                      |
| --max-etag-size=\<size\>             | 64MiB         | 0-\*                    | Maximium size to generate ETags for.                      |
| --reverse-proxy                      | false         | true, false             | Require X-Real-IP and X-Forward-For.                      |
| --trusted-reverse-proxies=\<string\> | localhost     | host1,host2,...,hostn   | Comma delimitered list of trusted hosts.                  |
| --x-accel-redirect=\<path\>          | "" \[/./\]    | \*                      | Serve static content with X-Accel-Redirect (Nginx).       |
| --x-sendfile                         | false         | true, false             | Serve static content with X-Sendfile (mod_xsendfile).     |
| --chunk-size                         | 131072        | 0-\*                    | Number of bytes to send per chunk.                        |
| --scheduler-tick-rate=\<number\>     | 60            | 0-\*                    | The fallback tickrate (Hz) for a schedual that yields nil.|
| --max-post-length=\<number\>         | ""            | 0-\*, ""                | The maximum length of the post data.                      |


## Handle a Page

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

## Templating System

LuaServer comes with it's own templating system, you can still use `reqest:append(string)` should you choose to (eg,
implimenting your own templating system).
<!--- jist is not spelt incorrectly, gist = g for ghost, IMO, so yeah... --->
The default templating system offers the `tags` namespace.  The general jist is `tag [, attributes][, children]` where
attributes is a key-value table, and children is an indexed (array) or empty table (`table.Count(att) != #att`).

### Escaping

Escaping with the templating system is all done automatically, however, should you need to write HTML stored in text
to the templating system, then you should use the tag `tags.NOESCAPE` which will prevent the very next value from being
escaped.  Here is an example of it in use:

```lua
tags.html
{
	tags.NOESCAPE, "<script>alert('hi');</script>"
}
```

### Examples

#### Example 1 - Simple

```lua
local template = tags.p {class = "test"} { "Here, have some ", tags.b{ "boldness" }, "." }
print(template.to_html())
```

```html
<p class="test">
	Here, have some 
	<b>
		boldness
	</b>
	.
</p>
```

#### Example 2 - Basic Page

```lua
tags.html
{
	tags.head
	{
		tags.title
		{
			"Hello, world"
		}
	},
	tags.body
	{
		tags.div {class = "test"}
		{
			"This is a really nice generation thingy",
			tags.br, tags.br,
			"Do you like my logo?",
			tags.br,
			tags.img {src = "/logo.png"}
		}
	}
}.print()
```

```html
<html>
	<head>
		<title>
			Hello, world
		</title>
	</head>
	<body>
		<div class="test">
			This is a really nice generation thingy
			<br />
			<br />
			Do you like my logo?
			<br />
			<img src="/logo.png" />
		</div>
	</body>
</html>
```

#### Example 3 - Segmants

```lua
local template = tags.div {class = "comments"}
{
	tags.span {"Comments:"},
	tags.SECTION
}

template.to_request(req, 0)
	for i = 1, 5 do
		tags.div {class = "comment"}
		{
			tags.span {class = "author"} { "Anon" .. i },
			tags.span {class = "message"} { "This is a test message." }
		}.to_request(req)
	end
template.to_request(req, 1)
```

```html
<div class="comments">
	<span>
		Comments:
	</span>
	<div class="comment">
		<span class="author">
			Anon 1
		</span>
		<span class="message">
			This is a test message.
		</span>
	</div>
	<!--- ... --->
	<div class="comment">
		<span class="author">
			Anon 5
		</span>
		<span class="message">
			This is a test message.
		</span>
	</div>
</div>
```

#### Example 4 - Unpack

```lua
local comments = {}
for i = 1, 5 do
	local comment = tags.div {class = "comment"}
	{
		tags.span {class = "author"} { "Anon" .. i },
		tags.span {class = "message"} { "This is a test message." }
	}
	table.insert(comments, comment)
end

local template = tags.div {class = "comments"}
{
	tags.span {"Comments:"},
	unpack(comments)
}
print(template.to_html())
```

```html
<div class="comments">
	<span>
		Comments:
	</span>
	<div class="comment">
		<span class="author">
			Anon 1
		</span>
		<span class="message">
			This is a test message.
		</span>
	</div>
	<!--- ... --->
	<div class="comment">
		<span class="author">
			Anon 5
		</span>
		<span class="message">
			This is a test message.
		</span>
	</div>
</div>
```

## Overriding Default Handler

The following code will remove the hook used by reqs, so you can impliment your own if you desire

```lua
hook.Remove("Request", "default")
hook.Add("Request", "mine", function(req, res)
	-- ...
end)
```

# Behind Nginx

It is recommended that you run LuaServer behind Nginx to prevent many types of attacks, and other things
provided by Nginx, such as compression.  The daemon runs as the user `daemon`, so it's recommended you also run Nginx with the user `daemon` too.

## HTTP

Example Nginx config:

```nginx
server {
	listen 80;
	listen [::]:80;

	server_name localhost;

	location / {
		include /etc/nginx/proxy_params;
		proxy_pass http://localhost:8080;
	}
	location /./ { # this is for X-Accel-Redirect
		internal;
		root /usr/share/luaserver/;
	}
}
```

## HTTPS

For HTTPS, allthough this behaviour is inbuilt into LuaServer, if you're running through Nginx, then
you should also create a server to handle HTTPS.  For exmaple:

```nginx
server {
	listen 443      ssl spdy;
	listen [::]:443 ssl spdy;

	ssl_certificate cert.pem;
	ssl_certificate_key cert.key;

	ssl_session_timeout 5m;

	ssl_protocols SSLv3 TLSv1;
	ssl_ciphers ALL:!ADH:!EXPORT56:RC4+RSA:+HIGH:+MEDIUM:+LOW:+SSLv3:+EXP;
	ssl_prefer_server_ciphers on;

	server_name localhost;

	location / {
		include /etc/nginx/proxy_params;
		# proxy_set_header X-Forwarded-Ssl on;
		proxy_pass http://localhost:8080;
	}
	location /./ { # this is for X-Accel-Redirect
		internal;
		root /usr/share/luaserver/;
	}
}

```

# To Do
<!--- U+2610 (☐, 'BALLOT BOX'), U+2611 (☑, 'BALLOT BOX WITH CHECK'), and U+2612 (☒, 'BALLOT BOX WITH X') --->

- [x] Cookie Support
- [x] Session libary
- [ ] Global table support for sessions
- [ ] Rewrite template generate_html to be cleaner & easier to follow
- [x] Add the additional command --help
- [x] Add the additional command --version
- [ ] Remove other threading methods, only keep coroutines

# Functions Provided

## hook

`hook.Add(name, id, callback)`  

`hook.Remove(name, id)`  

`hook.Call(name)`  

`hook.PushFatalErrors()`  

`hook.PopFatalErrors()`  

## reqs:

`reqs.AddPattern(host, url, callback)`

## Request:

`Request(clilent)`  

`request:method()`  

`request:params()`  

`request:post_data()`  

`request:post_string()`  

`request:headers()`  

`request:url()`  

`request:full_url()`  

`request:parsed_url()`  

`request:client()`  

`request:start_time()`  

`request:total_time()`  

`request:peer()`  
	
## Response:

`Response(request)`  

`response:request()`  

`response:client()`  

`response:set_status(what)`  

`response:append(str)`  

`response:clear()`  

`response:set_file(path)`  

`response:set_header(name, value)`  

`response:send()`  

## util:

`PrintTable(tbl, done = {}, depth = 0)`  

`include(file)`  

`expects(...)`  

`util.time()`  

`util.ItterateDir(dir, recursive, callback, ...) `  

`util.DirExists(dir)`  

`util.Dir(base_dir, recursive)`  

`util.EnsurePath(path)`  

## table: (extension)

`table.Count(tbl)`  

`table.IsEmpty(tbl)`  

`table.HasKey(tbl, key)`  

`table.HasValue(tbl, value)`  

`table.ToString(tbl)`  

## string: (extension)

`string.StartsWith(haystack, needle)`  

`string.EndsWith(haystack, needle)`  

`string.Replace(str, what, with)`  

`string.Path(self)`  

`string.ReplaceLast(str, what, with)`  

`string.Trim(str)`  

`string.Split(self, delimiter)`  

## math: (extension)

`math.Round(what, prec)`  

## escape:

`escape.pattern(input)`  

`escape.html(input [, strict])`  

`escape.striptags(input)`  

`escape.sql(input)`  

`escape.argument(input)`  

## os:

`os.capture(cmd [, raw])`  

`os.platform()`  

## script:

`script.pid()`  

`script.current_file([depth])`  

`script.current_path([depth])`  

`script.local_path(path)`  

`script.instance_info()`  

`script.parse_arguments(args [, shorthands])`  

## stack:

`stack()`  

`stack:push(val)`  

`stack:pop()`  

`stack:value()`  

`stack:all()`  
