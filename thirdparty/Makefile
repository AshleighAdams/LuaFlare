include config.post

# Commands prefixed with an underscore (i.e. _SERVICE) are "post installation"
# commands. When procucing packages, these may be overridden to log the commands
# needed to be ran.

all:

%:

clean:
	$(RM) *.post

check-dependencies:
	@echo -n "checking config version..."
	@if [ "$(GIT_VERSION)" != "$(CONFIGURE_VERSION)" ]; then \
		echo -e " fail.\n config is outdated, re-run ./configure"; \
		exit 1; \
	else \
		echo " okay. ($(VERSION))"; \
	fi
	
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
		> "$(LUAFLARE_LIB_DIR)/luaflare.lua" && \
	$(CHMOD) +x "$(LUAFLARE_LIB_DIR)/luaflare.lua"
	
	$(INSTALL) luaflare.post "$(LUAFLARE_BIN_DIR)/luaflare"
	$(CHMOD) +x "$(LUAFLARE_BIN_DIR)/luaflare"

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
	
	$(INSTALL) luaflare.default.post "$(SYSCONF)/default/luaflare"
	
	$(TOUCH) $(LUAFLARE_CFG_DIR)/luaflare.cfg
	
	# allthough libs/luaflare.lua has already been copied, copy it again, but replace the version number
	$(CAT) ../libs/luaflare.lua \
		| $(SED) "s|LuaFlare git|LuaFlare $(VERSION)|g" \
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
	$(INSTALL) luaflare.systemd.post $(SYSTEMD_UNIT_DIR)/luaflare.service
	$(_SYSTEMCTL) daemon-reload && \
	$(_SYSTEMCTL) enable luaflare.service && \
	$(_SYSTEMCTL) restart luaflare.service

install-sysvinit-service:
	$(INSTALL) luaflare.sysvinit.post $(SYSVINIT_DAEMON_DIR)/luaflare && \
	$(CHMOD) +x $(SYSVINIT_DAEMON_DIR)/luaflare
	
	$(_UPDATE_RC_D) luaflare defaults && \
	$(_SERVICE) luaflare start
	
install-upstart-service:
	$(INSTALL) luaflare.upstart.post $(UPSTART_DAEMON_DIR)/luaflare.conf
	$(_SERVICE) luaflare start

install-nginx-site:
	$(MKDIR) "$(NGINX_DIR)/sites-available/" && \
	$(MKDIR) "$(NGINX_DIR)/sites-enabled/" && \
	$(INSTALL) luaflare.nginx.post "$(NGINX_DIR)/sites-available/luaflare"
	
	# Don't enable these by default, they error unless the default site has been removed!
	#$(_LN) $(NGINX_DIR_STR)/sites-available/luaflare $(NGINX_DIR_STR)/sites-enabled/luaflare
	#$(_SERVICE) nginx restart # systemd / upstart should impliment this

install-apache-site:
	$(MKDIR) "$(APACHE_DIR)/sites-available/" && \
	$(MKDIR) "$(APACHE_DIR)/sites-enabled/" && \
	$(INSTALL) luaflare.apache.post "$(APACHE_DIR)/sites-available/luaflare.conf"
	

install-bash-completion:
	$(INSTALL) luaflare.bash-completion.post "$(BASH_COMPLETION_DIR)/luaflare"
	$(CHMOD) +x "$(BASH_COMPLETION_DIR)/luaflare"

install: check-dependencies install-bin install-extra
