# LuaFlare luaparser library

`local parser = require("luaflare.util.luaparser")`

Tokenize Lua code.  Used for syntax extensions.

## `parser.strict`

Should the parser `error()` on an issue, or try to resume?

## `parser.problem(str, depth)`

Used when parsing Lua code to report a problem.

## `... parser.assert(check, [msg | ...])`

If check is falsy, and strict then error. else `return check, ...`.

## `parser.keywords`

A list of keywords in the format of `["keyword"] = true`.

Used to mark identifieres as keywords in the parser.

## `parser.tokenchars_joinable`

A list of chars that "compress" together to form one token.

## `parser.tokenchars_unjoinable`

A list of chars that each represent one token.

## `parser.escapers`

A list of valid string escapers in the form `pattern = function`.

## `parser.brackets_create`

Brackets that increase the bracket depth.

## `parser.brackets_destroy`

Brackets that decrease the bracket depth.

## `tokens parser.tokenize(string code)`

Turns `code` into a list of tokens.  Tokens are in the format of:

    {
    	type = string --[[ hashbang, comment, string, 
    	                   number, newline, whitespace,
    	                   token, keyword, identifier,
    	                   unknown, or more... ]]
    	value = string,
    	range = {from, to},
    	chunk = string,
    }

## `parser.scope_create`

A list of keywords (`["keyword"] = true`) that create scopes.

## `parser.scope_destroy`

A list of keywords (`["keyword"] = true`) that destroy scopes.

## `rootscope parser.read_scopes(table tokens)`

Attempts to match scopes to the tokens.

Scopes are in the format:

    {
        starts = number,
        ends = number,
        starttoken = token,
        locals = table,
        children = table
    }


