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
	$(MKDIR) $(LUAFLARE_BIN_DIR) && \
	$(CAT) ../luaflare.lua \
		| $(SED) "s|#!/usr/bin/env lua|#!/usr/bin/env $(LUA)|" \
		> $(LUAFLARE_BIN_DIR)/luaflare && \
	$(CHMOD) +x $(LUAFLARE_BIN_DIR)/luaflare

install-luaflare-opts:
	$(PRECMD) $(LUAFLARE_BIN_DIR_STR)/luaflare $(LUAFLARE_POSTINT_OPTS)
ifneq ($(SERVICE_SYSTEM),none)
	$(_SERVICE) luaflare restart
endif

install-shared-files:
	$(MKDIR) $(LUAFLARE_LIB_DIR)
	$(MKDIR) $(LUAFLARE_CFG_DIR)
	# make sure they don't exist, then recursive copy them!
	$(CP) -r ../inc    $(LUAFLARE_LIB_DIR)/
	$(CP) -r ../libs   $(LUAFLARE_LIB_DIR)/
	$(CP) -r ../lua    $(LUAFLARE_CFG_DIR)/
	$(CP) -r ../static $(LUAFLARE_CFG_DIR)/
	$(CP) -r ../keys   $(LUAFLARE_CFG_DIR)/
	
	# allthough libs/luaflare.lua has already been copied, copy it again, but replace the version number
	$(CAT) ../libs/luaflare.lua \
		| $(SED) "s|LuaFlare git|LuaFlare $(VERSION)|g" \
		| $(SED) "s|\".\", -- config-marker|\"$(LUAFLARE_CFG_DIR_STR)\",|g" \
		| $(SED) "s|\".\", -- lib-marker|\"$(LUAFLARE_LIB_DIR_STR)\",|g" \
		> $(LUAFLARE_LIB_DIR)/libs/luaflare.lua
	
	$(MKDIR) $(LUAFLARE_CFG_DIR)/sessions
	$(MKDIR) $(LUAFLARE_CFG_DIR)/sites
	
	# $(CP) -r ../luaflare.cfg $(LUAFLARE_CFG_DIR)/luaflare.cfg

install-shared-ownership:
	$(_CHOWN) -R $(USER):$(USER) $(LUAFLARE_LIB_DIR_STR)/
	$(_CHOWN) -R $(USER):$(USER) $(LUAFLARE_CFG_DIR_STR)/

install-shared: install-shared-files install-shared-ownership

install-none-service:
	# do nothing

install-systemd-service:
	$(MKDIR) "$(SYSTEMD_UNIT_DIR)" && \
	$(CAT) luaflare.systemd \
		| $(SED) "s|LUAFLARE_LIB_DIR|$(LUAFLARE_LIB_DIR_STR)|g" \
		| $(SED) "s|LUAFLARE_CFG_DIR|$(LUAFLARE_CFG_DIR_STR)|g" \
		| $(SED) "s|LUAFLARE_BIN_DIR|$(LUAFLARE_BIN_DIR_STR)|g" \
		| $(SED) "s|USER|$(USER)|g" \
		> $(SYSTEMD_UNIT_DIR)/luaflare.service
	$(_SYSTEMCTL) daemon-reload && \
	$(_SYSTEMCTL) enable luaflare.service && \
	$(_SYSTEMCTL) restart luaflare.service

install-sysvinit-service:
	$(MKDIR) "$(SYSVINIT_DAEMON_DIR)" && \
	$(CAT) luaflare.sysvinit \
		| $(SED) "s|LUAFLARE_LIB_DIR|$(LUAFLARE_LIB_DIR_STR)|g" \
		| $(SED) "s|LUAFLARE_CFG_DIR|$(LUAFLARE_CFG_DIR_STR)|g" \
		| $(SED) "s|LUAFLARE_BIN_DIR|$(LUAFLARE_BIN_DIR_STR)|g" \
		| $(SED) "s|_USER|$(USER)|g" \
		> $(SYSVINIT_DAEMON_DIR)/luaflare && \
	$(CHMOD) +x $(SYSVINIT_DAEMON_DIR)/luaflare && \
	$(_UPDATE_RC_D) luaflare defaults && \
	$(_SERVICE) luaflare start
	
install-upstart-service:
	$(MKDIR) "$(UPSTART_DAEMON_DIR)" && \
	$(CAT) luaflare.upstart \
		| $(SED) "s|LUAFLARE_LIB_DIR|$(LUAFLARE_LIB_DIR_STR)|g" \
		| $(SED) "s|LUAFLARE_CFG_DIR|$(LUAFLARE_CFG_DIR_STR)|g" \
		| $(SED) "s|LUAFLARE_BIN_DIR|$(LUAFLARE_BIN_DIR_STR)|g" \
		| $(SED) "s|USER|$(USER)|g" \
		> $(UPSTART_DAEMON_DIR)/luaflare.conf && \
	$(_SERVICE) luaflare start

install-nginx-site:
	$(MKDIR) "$(NGINX_DIR)/sites-available/" && \
	$(MKDIR) "$(NGINX_DIR)/sites-enabled/" && \
	$(CAT) luaflare.nginx \
		| $(SED) "s|NGINX_SITE_HTTP_PORT|$(NGINX_SITE_HTTP_PORT)|g" \
		| $(SED) "s|NGINX_SITE_HTTPS_PORT|$(NGINX_SITE_HTTPS_PORT)|g" \
		| $(SED) "s|LUAFLARE_LIB_DIR|$(LUAFLARE_LIB_DIR_STR)|g" \
		| $(SED) "s|LUAFLARE_CFG_DIR|$(LUAFLARE_CFG_DIR_STR)|g" \
		| $(SED) "s|LUAFLARE_PORT|$(LUAFLARE_PORT)|g" \
		> "$(NGINX_DIR)/sites-available/luaflare";
	
	# Don't enable these by default, they error unless the default site has been removed!
	#$(_LN) $(NGINX_DIR_STR)/sites-available/luaflare $(NGINX_DIR_STR)/sites-enabled/luaflare
	#$(_SERVICE) nginx restart # systemd / upstart should impliment this

install-bash-completion:
	$(MKDIR) "$(BASH_COMPLETION_DIR)" && \
	$(CAT) luaflare.bash-completion \
		| $(SED) "s|LUAFLARE_LIB_DIR|$(LUAFLARE_LIB_DIR_STR)|g" \
		| $(SED) "s|LUAFLARE_CFG_DIR|$(LUAFLARE_CFG_DIR_STR)|g" \
	> "$(BASH_COMPLETION_DIR)/luaflare"

install: check-dependencies install-bin install-extra
