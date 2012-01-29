
function SendChat()
{
	var str = escape(document.getElementById("tosay").value);
	document.getElementById("tosay").value = "";
	var url = "/chatapi.lua?action=msg&msg=" + str;
	
	$.get(url, function(response) {
		
	});
	
	return false;
}

function Update()
{
	var url = "/chatapi.lua?action=getnewmsgs"
	$.get(url, function(response) {
		document.getElementById("chatbox").value += response;
		document.getElementById("chatbox").scrollTop = document.getElementById("chatbox").scrollHeight;
	});
	setTimeout("Update()", 500);
}

function UpdateStart()
{
	var url = "/chatapi.lua?action=getallmsgs"
	$.get(url, function(response) {
		document.getElementById("chatbox").value += response;
		document.getElementById("chatbox").scrollTop = document.getElementById("chatbox").scrollHeight;
	});
	setTimeout("Update()", 500);
}

setTimeout("UpdateStart()", 1000);
