
include("inc/detector.lua")

site = Site()

site.write_header(GET.title or "N/A")

writef("Hello, %s!\n", EscapeHTML(GET.name) or "Anon")

site.write_footer()

