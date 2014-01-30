websocket = {}
websocket.TEXT = 129

local sha1 = require("sha1")
local vstruct = require("vstruct")

local b = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
function base64(data)
    return ((data:gsub('.', function(x) 
        local r,b='',x:byte()
        for i=8,1,-1 do r=r..(b%2^i-b%2^(i-1)>0 and '1' or '0') end
        return r;
    end)..'0000'):gsub('%d%d%d?%d?%d?%d?', function(x)
        if (#x < 6) then return '' end
        local c=0
        for i=1,6 do c=c+(x:sub(i,i)=='1' and 2^(6-i) or 0) end
        return b:sub(c+1,c+1)
    end)..({ '', '==', '=' })[#data%3+1])
end

local function send_message(client, payload)
	local len = payload:len()
	local header
	local mode =  websocket.TEXT
	
	if len < 126 then
		header = {string.char(mode), string.char(len)}
	elseif len < 65536 then
		header = {
			string.char(mode),
			string.char(126),
			bit.band( bit.rshift(len, 8) , 255),
			bit.band( len                , 255),
		}
	else
		header = {
			string.char(mode),
			string.char(127),
			bit.band( bit.rshift(len, 56) , 255),
			bit.band( bit.rshift(len, 48) , 255),
			bit.band( bit.rshift(len, 40) , 255),
			bit.band( bit.rshift(len, 32) , 255),
			bit.band( bit.rshift(len, 24) , 255),
			bit.band( bit.rshift(len, 16) , 255),
			bit.band( bit.rshift(len,  8) , 255),
			bit.band( len                 , 255),
		}
	end
	
	client:send(string.format("%s%s", table.concat(header, ""), payload))
end

local function Upgrade_websocket(request, response)
	local client = request:client()
	request:set_upgraded()
	
	local key      = request:headers()["Sec-WebSocket-Key"]
	local protocol = request:headers()["Sec-WebSocket-Protocol"]
	local version  = request:headers()["Sec-WebSocket-Version"]
	
	if not key or not protocol or not version then
		print(key, protocol, version)
		response:set_status(501)
		response:send()
		return
	end
	
	local hash = base64(sha1.binary(key .. "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"))
	
	print(string.format("websocket: %s: generated the hash %s from key %s", protocol, hash, key))
	
	response:clear_headers()
	response:set_status(101)
	response:set_header("Upgrade", "websocket")
	response:set_header("Connection", "Upgrade")
	response:set_header("Sec-WebSocket-Accept", hash)
	response:set_header("Sec-WebSocket-Protocol", protocol)
	response:send()
	
	-- client now should be a websocket protocol
	--while true do
		send_message(client, "hello")
		send_message(client, "world")
		--client:send("hello\n")
	--end
end

reqs.Upgrades["websocket"] = Upgrade_websocket

reqs.AddPattern("*", "/websocket", function(req, res)
	tags.html
	{
		tags.head
		{
			tags.script { type = "text/javascript", src = "//ajax.googleapis.com/ajax/libs/jquery/1.10.2/jquery.min.js" },
			tags.script
			{
				tags.NOESCAPE,
				[[
					$( document ).ready(function()
					{
						con = new WebSocket("ws://localhost:8080/test", "tty");    
						con.onopen = function() { document.write("open<br/>") }
						con.onmessage = function(event) { document.write("data: " + event.data + "<br/>") }
						con.onclose = function(event) { document.write("close<br/>") }
					})
				]]
			}
		},
		tags.body
		{
		}
	}.to_response(res)
end)