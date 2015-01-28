# LuaFlare templator library

`local templator = require("luaflare.templator")`

## `generator templator.generate(string input)`

The input format is in normal HTML (usually), and markers are placed inline in
the string with the format "$(name, escaper)".
If `escaper` isn't present, it will default to "html".

A generator object is built and then returned. 

## `string generator(table values)`

Build the final output, with the values from `values`.
The indentation levels of the marked values are preserved across newlines.

## Example

	local gen = templator.generate [[
	<html>
		<head>
			<title>$(title)</title>
		</head>
		<body>
			<h1>$(title)</h1>
			Hello, you requested the URL: $(url)
			<br/>
			$(contents)
			<br/>
			$(dont_escape, none)
		</body>
	</html>
	]]
	
	local final = gen {
		title = "Test",
		url = "/world",
		contents = "An example of how\nindentation <is> preserved over newlines.",
		dont_escape = "This is <em>not</em> escaped!"
	}
	
	print(final)

Will print the following output:

	<html>
		<head>
			<title>Test</title>
		</head>
		<body>
			<h1>Test</h1>
			Hello, you requested the URL: /world
			<br/>
			An example of how
			<br />
			indentation &lt;is&gt; preserved over newlines.
			<br/>
			This is <em>not</em> escaped!
		</body>
	</html>

## With `luaflare.tags`

Because the tags library is inherently slow,
you can use the tags to generate the HTML on load,
then use templator to fill in the values quickly.

The cost of calling the generator is very cheap, as it iterates a small table,
updating relevant indexes with their new escaped values,
and then concatenating the final results together.
The above example takes approximately ~10us (~0.01ms) on an i5, under `lua5.2`,
while the same example with `tags` is usually an order of magnitude slower.

	local gen = templator.generate(tags.html
	{
		tags.head
		{
			tags.title { "$(title)" }
		},
		tags.body
		{
			tags.h1 { "$(title)" },
			"Hello, you requested the URL: $(url)",
			tags.br,
			"$(contents)",
			tags.br,
			"$(dont_escape, none)"
		}
	}.to_html())
