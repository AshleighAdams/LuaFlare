# LuaFlare virtualfilesystem library

`local vfs = require("luaflare.virtualfilesystem")`

## `string vfs.locate(string path, boolean fallback = false)`

Translates site relative file locations relative to the current working directory.

## `array vfs.ls(string path, table options = {})`

Returns a list of files and folders.

List of valid options:

 - `type`: The type (mode) of the file **must** match this.
           The type of file may be of either `directory`, `file`, `link`,
           `socket`, `named pipe`, `char device`, `block device`, or `other`.
 - `recursive`: When encountering another directory, should we recurse into it?
 - `tester`: A function to test each file.  The arguments passed are: `string file, table options, table attributes, boolean default`.
