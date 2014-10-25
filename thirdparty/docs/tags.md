# LuaServer tags libary

`local tags = require("luaserver.tags")`

Provides HTML generation with automatic escaping.

## `string tbl.to_html(section = 0)`

Returns the HTML tbl represents.

## `string tbl.print(section = 0)`

Writes the HTML to stdout.

## `string tbl.to_response(section = 0)`

Writes the HTML to the response.

## Valid Tags

Access via `tags.$name`.

Use like:

    tags.div {attrib1 = "value", attrib2 = value}
    {
    	tags.em { "Children" }
    }.to_(html|response)


     Name     | Options                        | Special Function
    ----------|--------------------------------|---------------------------
     SECTION  |                                | Mark a section; no output 
     NOESCAPE |                                | Don't escape the next element.
     html     | pre text = "<!DOCTYPE html>\n" |
     head     |                                |
     body     |                                |
     script   | escaper = striptags            |
     style    | escaper = striptags            |
     link     | empty element                  |
     meta     | empty element                  |
     title    | inline                         |
     div      |                                |
     header   |                                |
     main     |                                |
     footer   |                                |
     br       | inline, empty element          |
     img      | empty element                  |
     image    | empty element                  |
     a        | inline                         |
     p        | inline                         |
     span     | inline                         |
     code     | inline                         |
     h1       | inline                         |
     h2       | inline                         |
     h3       | inline                         |
     h4       | inline                         |
     h5       | inline                         |
     h6       | inline                         |
     b        | inline                         |
     i        | inline                         |
     em       | inline                         |
     u        | inline                         |
     center   | inline                         |
     pre      |                                |
     table    |                                |
     ul       |                                |
     li       | inline                         |
     tr       |                                |
     td       |                                |
     tc       |                                |
     form     |                                |
     input    |                                |
     textarea |                                |
