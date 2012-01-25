<?lua
local function m_PrintTable(tbl, donetbls, depth)
	donetbls = donetbls or {}
	depth = depth or 0
	
	if donetbls[tbl] then return end -- prevent stack overflows
	
	donetbls[tbl] = true
	local tabs = string.rep("<td></td>", depth)
	
	for k,v in pairs(tbl) do
		if type (v) == "table" then
			writef("<tr>%s<td>%s:</td><td>%s</td></tr>\n", tabs, EscapeHTML(tostring(k)), EscapeHTML(tostring(v)))
			m_PrintTable(tbl[k], donetbls, depth + 1)
		else
			writef("<tr>%s<td>%s</td><td>%s</td></tr>\n", tabs, EscapeHTML(tostring(k)), EscapeHTML(tostring(v)))
		end
	end
end

function PrintTable(tbl, metadata)
	writef("<table %s >\n", metadata or "")
	m_PrintTable(tbl)
	write("</table>\n")
end

?>
