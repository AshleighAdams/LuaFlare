return {
	_VERSION     = "LuaFlare git",
	config_path  = os.getenv("LUAFLARE_CFG_DIR") or ".",
	lib_path     = os.getenv("LUAFLARE_LIB_DIR") or ".",
	--[[hook         = require("luaflare.hook"),
	hosts        = require("luaflare.hosts"),
	httpstatus   = require("luaflare.httpstatus"),
	mimetypes    = require("luaflare.mimetypes"),
	scheduler    = require("luaflare.scheduler"),
	session      = require("luaflare.session"),
	tags         = require("luaflare.tags"),
	threadpool   = require("luaflare.threadpool"),
	util         = require("luaflare.util"),
	websocket    = require("luaflare.websocket"),]]
}
