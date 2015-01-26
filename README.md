LuaFlare [![Build Status](https://travis-ci.org/KateAdams/LuaFlare.svg?branch=master)](https://travis-ci.org/KateAdams/LuaFlare)
=========
	
# Documentation

The files that match the pattern lua/\*/ar_\*.lua will be automatically ran at the start, and when they're modified. Use
`include(file)` to include files relative to your directory, and to specify files that your script depends on, so that
they may be automatically reloaded too.

## Handle a Page

```lua
local hosts = require("luaflare.hosts")
local domain = hosts.get("domain.tld")

-- callback is of type function(request, response, captures...)
domain:add(static_path, callback)
domain:addpattern(pattern_path, callback)

domain:add("/hello_world", hello_world)
domain:addpattern("/hello_(*)", hello_any)

domain:addpattern("/user/(%d+)/message", send_user_message)
```

## Templating System

LuaFlare comes with it's own templating system, you can still use `reqest:append(string)` should you choose to (eg,
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
	<!-- ... -->
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
	<!-- ... -->
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
hook.remove("Request", "default")
hook.add("Request", "mine", function(req, res)
	-- ...
end)
```

# Reverse Proxy

LuaFlare by default is expecting to be ran behind a reverse proxy.
This allows sending files via X-Accel-Redirect or X-Sendfile, and protects LuaFlare against many types of attacks.

When being configured, if Nginx or Apache has been found,
then their respective sites will be installed upon `make install`.

See `thirdparty/luaflare.nginx.(pre|post)`
and `thirdparty/luaflare.apache.(pre|post)`
for the sites themselves (pre and post configure).

# To Do
<!--- U+2610 (☐, 'BALLOT BOX'), U+2611 (☑, 'BALLOT BOX WITH CHECK'), and U+2612 (☒, 'BALLOT BOX WITH X') --->

- [x] Cookie Support
 - [ ] Aditional cookie support for timing out, etc...
- [ ] Global table support for sessions?
- [ ] Rewrite template generate_html to be cleaner, easier to follow, and quicker.
- [ ] If a main thread dies, CPU usage goes to full.  Fix this.
- [X] Standard socket API
 - [X] LuaSocket backend
 - [ ] POSIX backend
 - [ ] LuaFlare code over from LuaSocket to luaflare.socket standard API
- [ ] Clean up the horrific mess that is the threading model. It should use
      the require system.
- [ ] Move script options into the bootstrapper.

To look at:

- inc/request.lua:`read_headers()`: should continuations of headers insert a space, newline, or nothing?
	- `ret[lastheader] = ret[lastheader] .. " " .. val:trim()`

# Templating Concept

```lua
$$ = $
$(arg, escaper) = escape[escaper](arg)
$(arg) = $(arg, html)

-- these also can be generated with the tags library
local body_html = [[
<html>
	<head>
		<title>$(title)</title>
	</head>
	<body>
		$(contents, none)
	</body>
</html>
]]

local content_html = [[
<h1>Hello, $(url)!</h1>
<p>You requested $(url)</p>
]]

local body = templator.generate(body_html)
local content = templator.generate(content_html)

function test(req, res)
	local html = body {
		title = req:url(),
		contents = content {
			url = req:url()
		}
	}
	res:append(html)
end
host.any:add("/test", test)
```

using tags

```lua
local body_html = tags.html
{
	tags.head
	{
		tags.title { "$(title)" }
	},
	tags.body
	{
		"$(contents, none)"
	}
}.to_string()

local content_html = tags.div
{
	tags.h1 { "Hello, $(url)" },
	tags.p { "You requested $(url)" }
}.to_string()
```

# Host

static over pattern?

For example, the exact resource `/path/file.ext` exists, but a pattern for
`/path/(*)` exists and will be matched; should we allow the exact match to
overrule pattern matching?

# Packaging concept

	luaflare
		Recommends: luaflare-service, luaflare-reverseproxy
	
	luaflare-reverseproxy-nginx: installs nginx-related files for luaflare
		Depends: luaflare, nginx
		Provides: luaflare-reverseproxy
	luaflare-reverseproxy-apache: installs apache-related files for luaflare
		Depends: luaflare, apache
		Provides: luaflare-reverseproxy
	
	luaflare-service: installs luaflare daemons
		Depends: luaflare, systemd | sysvinit | upstart

You can see this packaging concept implimented here: https://github.com/KateAdams/LuaFlare-debian/

# New CLI Options

When a new command line option is added, make sure you update the following files to match:

 - thirdparty/docs/command-line-arguments.md
 - thirdparty/docs/luaflare.1
 - luaflare.lua
