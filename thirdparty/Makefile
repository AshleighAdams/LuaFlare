include config

# Commands prefixed with an underscore (i.e. _SERVICE) are "post installation"
# commands. When procucing packages, these may be overridden to log the commands
# needed to be ran.

all:

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

install-bin: install-shared
	$(MKDIR) $(LUASERVER_BIN_DIR) && \
	$(CAT) ../luaflare.lua \
		| $(SED) "s|#!/usr/bin/env lua|#!/usr/bin/env $(LUA)|" \
		> $(LUASERVER_BIN_DIR)/luaflare && \
	$(CHMOD) +x $(LUASERVER_BIN_DIR)/luaflare

install-luaflare-opts: install-bin install-shared
	$(PRECMD) $(LUASERVER_BIN_DIR_STR)/luaflare $(LUASERVER_POSTINT_OPTS)
ifneq ($(SERVICE_SYSTEM),none)
	$(_SERVICE) luaflare restart
endif

install-shared-files:
	$(MKDIR) $(LUASERVER_LIB_DIR)
	$(MKDIR) $(LUASERVER_CFG_DIR)
	# make sure they don't exist, then recursive copy them!
	$(CP) -r ../inc    $(LUASERVER_LIB_DIR)/
	$(CP) -r ../libs   $(LUASERVER_LIB_DIR)/
	$(CP) -r ../lua    $(LUASERVER_CFG_DIR)/
	$(CP) -r ../static $(LUASERVER_CFG_DIR)/
	$(CP) -r ../keys   $(LUASERVER_CFG_DIR)/
	
	# allthough libs/luaflare.lua has already been copied, copy it again, but replace the version number
	$(CAT) ../libs/luaflare.lua \
		| $(SED) "s|LuaFlare git|LuaFlare $(VERSION)|g" \
		| $(SED) "s|\".\", -- config-marker|\"$(LUASERVER_CFG_DIR_STR)\",|g" \
		| $(SED) "s|\".\", -- lib-marker|\"$(LUASERVER_LIB_DIR_STR)\",|g" \
		> $(LUASERVER_LIB_DIR)/libs/luaflare.lua
	
	$(MKDIR) $(LUASERVER_CFG_DIR)/sessions
	$(MKDIR) $(LUASERVER_CFG_DIR)/sites
	
	# $(CP) -r ../luaflare.cfg $(LUASERVER_CFG_DIR)/luaflare.cfg

install-shared-ownership:
	$(_CHOWN) -R $(USER):$(USER) $(LUASERVER_LIB_DIR_STR)/
	$(_CHOWN) -R $(USER):$(USER) $(LUASERVER_CFG_DIR_STR)/

install-shared: install-shared-files install-shared-ownership

install-none-service:
	# do nothing

install-systemd-service:
	$(MKDIR) "$(SYSTEMD_UNIT_DIR)" && \
	$(CAT) luaflare.systemd \
		| $(SED) "s|LUASERVER_LIB_DIR|$(LUASERVER_LIB_DIR_STR)|g" \
		| $(SED) "s|LUASERVER_CFG_DIR|$(LUASERVER_CFG_DIR_STR)|g" \
		| $(SED) "s|LUASERVER_BIN_DIR|$(LUASERVER_BIN_DIR_STR)|g" \
		| $(SED) "s|USER|$(USER)|g" \
		> $(SYSTEMD_UNIT_DIR)/luaflare.service
	$(_SYSTEMCTL) daemon-reload && \
	$(_SYSTEMCTL) enable luaflare.service && \
	$(_SYSTEMCTL) restart luaflare.service

install-sysvinit-service:
	$(MKDIR) "$(SYSVINIT_DAEMON_DIR)" && \
	$(CAT) luaflare.sysvinit \
		| $(SED) "s|LUASERVER_LIB_DIR|$(LUASERVER_LIB_DIR_STR)|g" \
		| $(SED) "s|LUASERVER_CFG_DIR|$(LUASERVER_CFG_DIR_STR)|g" \
		| $(SED) "s|LUASERVER_BIN_DIR|$(LUASERVER_BIN_DIR_STR)|g" \
		| $(SED) "s|_USER|$(USER)|g" \
		> $(SYSVINIT_DAEMON_DIR)/luaflare && \
	$(CHMOD) +x $(SYSVINIT_DAEMON_DIR)/luaflare && \
	$(_UPDATE_RC_D) luaflare defaults && \
	$(_SERVICE) luaflare start
	
install-upstart-service:
	$(MKDIR) "$(UPSTART_DAEMON_DIR)" && \
	$(CAT) luaflare.upstart \
		| $(SED) "s|LUASERVER_LIB_DIR|$(LUASERVER_LIB_DIR_STR)|g" \
		| $(SED) "s|LUASERVER_CFG_DIR|$(LUASERVER_CFG_DIR_STR)|g" \
		| $(SED) "s|LUASERVER_BIN_DIR|$(LUASERVER_BIN_DIR_STR)|g" \
		| $(SED) "s|USER|$(USER)|g" \
		> $(UPSTART_DAEMON_DIR)/luaflare.conf && \
	$(_SERVICE) luaflare start

install-nginx-site:
	$(MKDIR) "$(NGINX_DIR)/sites-available/" && \
	$(MKDIR) "$(NGINX_DIR)/sites-enabled/" && \
	$(CAT) luaflare.nginx \
		| $(SED) "s|NGINX_SITE_HTTP_PORT|$(NGINX_SITE_HTTP_PORT)|g" \
		| $(SED) "s|NGINX_SITE_HTTPS_PORT|$(NGINX_SITE_HTTPS_PORT)|g" \
		| $(SED) "s|LUASERVER_LIB_DIR|$(LUASERVER_LIB_DIR_STR)|g" \
		| $(SED) "s|LUASERVER_CFG_DIR|$(LUASERVER_CFG_DIR_STR)|g" \
		| $(SED) "s|LUASERVER_PORT|$(LUASERVER_PORT)|g" \
		> "$(NGINX_DIR)/sites-available/luaflare";
	
	$(LN) $(NGINX_DIR)/sites-available/luaflare $(NGINX_DIR)/sites-enabled/luaflare
	$(_SERVICE) nginx restart # systemd / upstart should impliment this

install-bash-completion:
	$(MKDIR) "$(BASH_COMPLETION_DIR)" && \
	$(CAT) luaflare.bash-completion \
		| $(SED) "s|LUASERVER_LIB_DIR|$(LUASERVER_LIB_DIR_STR)|g" \
		| $(SED) "s|LUASERVER_CFG_DIR|$(LUASERVER_CFG_DIR_STR)|g" \
	> "$(BASH_COMPLETION_DIR)/luaflare"

install: check-dependencies install-bin install-extra
