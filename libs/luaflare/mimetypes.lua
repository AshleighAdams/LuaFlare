local hook = require("luaflare.hook")

local mimetypes = {}

mimetypes.types = { -- basic types
	-- text
	["html"] = "text/html",
	["txt"] = "text/plain",
	["text"] = "text/plain",
	["md"] = "text/x-markdown",
	-- images
	["png"] = "image/png",
	["apng"] = "image/apng",
	["jpeg"] = "image/jpeg",
	["jpg"] = "image/jpeg",
	["gif"] = "image/gif",
	["bmp"] = "image/x-ms-bmp",
	["ico"] = "image/vnd.microsoft.icon",
	["tiff"] = "image/tiff",
	["tif"] = "image/tiff",
	["svg"] = "image/svg+xml",
	-- sound
	["wav"] = "audio/x-wav",
	["mp3"] = "audio/mpeg",
	-- video
	["avi"] = "video/x-msvideo",
	["mp4"] = "video/mp4",
	["mov"] = "video/quicktime",
	["qt"] = "video/quicktime",
	-- other
	["bin"] = "application/octet-stream"
}

function mimetypes.load()
	local file = io.open("/etc/mime.types", "r")
	
	if file then -- success, we found it
		for line in file:lines() do repeat
			line = line:trim()
			if line:starts_with("#") then break end
			
			local mimetype, exts = line:match("^(.-)%s+(.*)$")
			if mimetype == nil or exts == nil then break end	
		
			exts = exts:split(" ")
			for _, ext in ipairs(exts) do
				mimetypes.types[ext] = mimetype
			end
		until true end
	end
	
	print(string.format("loaded %i mime types", table.count(mimetypes.types)))
end
hook.add("Loaded", "load /etc/mime.types", mimetypes.load)

function mimetypes.guess(string path)
	local ext = path:match("^.*%.(.-)$") or ""
	return mimetypes.types[ext]
end

return mimetypes
