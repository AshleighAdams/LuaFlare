include config

LUA_DEPENDS = bit lfs md5 posix socket ssl xssfilter
ifeq ("$(SERVICE_SYSTEM)","systemd")	
	LUA_DEPENDS += systemd.daemon
endif

all: check-dependencies

check-dependencies:
	@if $(LUA) -v > /dev/null; then \
		echo "Lua$(LUA_VERSION) found"; \
	else \
		echo "Lua$(LUA_VERSION) not found"; \
		exit 1; \
	fi;
	@for dep in $(LUA_DEPENDS) ; do \
		echo -n "checking $$dep... "; \
		if $(LUA) -l $$dep -e "" 2> /dev/null; then \
			echo "okay"; \
		else \
			echo "fail"; \
			exit 1; \
		fi; \
	done

install-bin:
	$(CP) ../luaserver.lua $(PREFIX)/bin/luaserver

install-shared-files:
	$(MKDIR) $(LUASERVER_LIB_DIR)
	$(MKDIR) $(LUASERVER_CFG_DIR)
	# make sure they don't exist, then recursive copy them!
	$(CP) -r ../inc    $(LUASERVER_LIB_DIR)/
	$(CP) -r ../libs   $(LUASERVER_LIB_DIR)/
	$(CP) -r ../lua    $(LUASERVER_CFG_DIR)/
	$(CP) -r ../static $(LUASERVER_CFG_DIR)/
	$(CP) -r ../keys   $(LUASERVER_CFG_DIR)/
	
	# allthough libs/luaserver.lua has already been copied, copy it again, but replace the version number
	$(CAT) ../libs/luaserver.lua \
		| $(SED) "s|LuaServer git|LuaServer $(VERSION)|g" \
		| $(SED) "s|\".\", -- config-marker|\"$(LUASERVER_CFG_DIR_STR)\",|g" \
		| $(SED) "s|\".\", -- lib-marker|\"$(LUASERVER_LIB_DIR_STR)\",|g" \
		> $(LUASERVER_LIB_DIR)/libs/luaserver.lua
	
	$(MKDIR) $(LUASERVER_CFG_DIR)/sessions
	$(MKDIR) $(LUASERVER_CFG_DIR)/sites
	
	$(CP) -r ../luaserver.cfg $(LUASERVER_CFG_DIR)/luaserver.cfg

install-shared-ownership:
	chown -R $(USER):$(USER) $(LUASERVER_LIB_DIR)/
	chown -R $(USER):$(USER) $(LUASERVER_CFG_DIR)/

install-shared: install-shared-files install-shared-ownership

install-service:
ifeq ($(SERVICE_SYSTEM),systemd)
	$(CAT) luaserver.service \
		| $(SED) "s|LUASERVER_LIB_DIR|$(LUASERVER_LIB_DIR_STR)|g" \
		| $(SED) "s|LUASERVER_CFG_DIR|$(LUASERVER_CFG_DIR_STR)|g" \
		> $(SYSTEMD_UNIT_DIR)/luaserver.service
	systemctl daemon-reload && \
	systemctl enable luaserver.service && \
	systemctl restart luaserver.service
else
ifeq ($(SERVICE_SYSTEM),sysvinit)
	$(error Sysvinit not imp)
else
ifeq ($(SERVICE_SYSTEM),upstart)
	$(error Upstart not imp)
else
	$(error Unknown service system $(SERVICE_SYSTEM))
endif
endif
endif

install-nginx-site:
	$(CAT) luaserver.nginx \
		| $(SED) "s|NGINX_SITE_HTTP_PORT|$(NGINX_SITE_HTTP_PORT)|g" \
		| $(SED) "s|NGINX_SITE_HTTPS_PORT|$(NGINX_SITE_HTTPS_PORT)|g" \
		| $(SED) "s|LUASERVER_LIB_DIR|$(LUASERVER_LIB_DIR_STR)|g" \
		| $(SED) "s|LUASERVER_CFG_DIR|$(LUASERVER_CFG_DIR_STR)|g" \
		> "$(NGINX_DIR)/sites-available/luaserver";
	
	$(LN) $(NGINX_DIR)/sites-available/luaserver $(NGINX_DIR)/sites-enabled/luaserver
	systemctl restart nginx.service

install-bash-completion:
	$(CAT) luaserver.bash-completion \
		| $(SED) "s|LUASERVER_LIB_DIR|$(LUASERVER_LIB_DIR_STR)|g" \
		| $(SED) "s|LUASERVER_CFG_DIR|$(LUASERVER_CFG_DIR_STR)|g" \
	> "$(BASH_COMPLETION_DIR)/luaserver"

install: install-bin install-shared install-extra
