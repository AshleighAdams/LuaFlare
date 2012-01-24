
dofile("localhost/inc/detector.lua")

site = Site()

site.write_header(con.GET.title or "N/A")

con.write("Hello, world!\n")

site.write_footer()

