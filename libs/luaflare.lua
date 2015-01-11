local luaflare = {}

luaflare._VERSION     = "LuaFlare git"
luaflare.config_path  = os.getenv("LUAFLARE_CFG_DIR") or "."
luaflare.lib_path     = os.getenv("LUAFLARE_LIB_DIR") or "."

return luaflare
