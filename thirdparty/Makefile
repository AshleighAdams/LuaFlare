# vars
PREFIX=$(DESTDIR)/usr
LUASERVER_DIR=$(PREFIX)/share/luaserver
USER=www-data
NGINX_DIR=$(DESTDIR)/etc/nginx
NGINX_SITE_HTTP_PORT=80
NGINX_SITE_HTTPS_PORT=443
LUA_DEPENDS=bit lfs md5 posix socket ssl systemd.daemon

# tools
CP=cp --remove-destination
MKDIR=mkdir -p

# auto
VERSION=`git describe --tags --always`
LUASERVER_DIR_STR=$(subst $(DESTDIR),,$(LUASERVER_DIR))

all:

check-dependencies:
	@for dep in $(LUA_DEPENDS) ; do \
		echo -n "checking $$dep... "; \
		if lua -l $$dep -e "" 2> /dev/null; then\
			echo "okay"; \
		else \
			echo "fail"; \
			exit 1; \
		fi; \
	done

install-bin:
	cp ../luaserver.lua $(PREFIX)/bin/luaserver

install-shared-files:
	$(MKDIR) $(LUASERVER_DIR)
	# make sure they don't exist, then recursive copy them!
	$(CP) -r ../inc    $(LUASERVER_DIR)/
	$(CP) -r ../libs   $(LUASERVER_DIR)/
	$(CP) -r ../lua    $(LUASERVER_DIR)/
	$(CP) -r ../static $(LUASERVER_DIR)/
	$(CP) -r ../keys   $(LUASERVER_DIR)/
	
	# allthough libs/luaserver.lua has already been copied, copy it again, but replace the version number
	cat ../libs/luaserver.lua | sed "s|LuaServer git|LuaServer $(VERSION)|g" > $(LUASERVER_DIR)/libs/luaserver.lua
	
	$(MKDIR) $(LUASERVER_DIR)/sessions
	$(MKDIR) $(LUASERVER_DIR)/sites
	
	$(CP) -r ../config.cfg $(LUASERVER_DIR)/config.cfg

install-shared-ownership:
	chown -R $(USER):$(USER) $(LUASERVER_DIR)/

install-shared: install-shared-files install-shared-ownership

install-service:
	$(CP) luaserver.service /etc/systemd/system/luaserver.service
	systemctl daemon-reload
	systemctl enable luaserver.service
	systemctl restart luaserver.service

install-nginx-site:
	cat luaserver.nginx | sed "s|NGINX_SITE_HTTP_PORT|$(NGINX_SITE_HTTP_PORT)|g" > /tmp/luaserver.nginx.1; \
	cat /tmp/luaserver.nginx.1 | sed "s|NGINX_SITE_HTTPS_PORT|$(NGINX_SITE_HTTPS_PORT)|g" > /tmp/luaserver.nginx.2; \
	cat /tmp/luaserver.nginx.2 | sed "s|LUASERVER_PATH|$(LUASERVER_DIR_STR)/|g" \
	 > "$(NGINX_DIR)/sites-available/luaserver";

	ln -sf $(NGINX_DIR)/sites-available/luaserver $(NGINX_DIR)/sites-enabled/luaserver
	systemctl restart nginx.service

install: check-dependencies install-bin install-shared install-service install-nginx-site
