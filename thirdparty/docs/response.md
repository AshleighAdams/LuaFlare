# LuaFlare response object

`local response = _G.Request(request)`

The object that represents a response.

## Hooks

### `"ListDirectory" request, response, string path[, table options]`

Called by `response:set_file()` if `can_list_directory` is truthy, and the target is a directory.

The function is expected to write to the response.

## `request response:request()`

Returns the request we're responding to.

## `tcpclient response:client()`

Returns the underlying tcpclient.

## `response:set_status(number what)`

Sets the HTTP status to `what`.

## `response:set_reply(string reply)`

Sets the response buffer, clearing it, if it wasn't already empty.

## `response:append(string data)`

Append to the response buffer.

## `string response:reply()`

Get the current response buffer.

## `number response:reply_length()`

Returns the current length of the response buffer.

## `response:clear()`

Clear everything (reset to default).

## `response:clear_headers()`

Clear the headers.

## `response:clear_content()`

Clear the content; retains the status code.

## `response:halt(number code, reason)`

Report an error, and call the appropriate hooks for an error.

### Example

    response:halt(403, "Not logged in")

## `response:set_file(string path[, table options])`

Sets the file to send.

If `X-Accel-Redirect` or `X-Sendfile` is on, it will use these to serve the file.

Valid options:

- `can_list_directory`:
	If the target is a directory, should we list the directory?

## `response:set_header(string name, any value)`

Sets the header to a value.

## `response:remove_header(string name)`

Removes a header completely.

## `response:set_cookie(string name, string value[, string path[, string domain[, number lifetime]]])`

Adds cookies to be sent.

## `response:etag()`

Returns a hash/mostly-unique string that changes when the content does.

## `response:use_etag()`

Returns whether we should use an etag.

Reasons they may not be used are:
	- Exceeds file-size limit.
	- Etags turned off.

## `response:send()`

Sends the request.

Once this has been sent, future calls to `send()` will do nothing.
