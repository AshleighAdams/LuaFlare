PREFIX=$(DESTDIR)/usr
LUASERVER_DIR=$(PREFIX)/share/luaserver
USER=daemon

CP=cp --remove-destination
MKDIR=mkdir -p

all:

install-bin:
	cp ../luaserver.lua $(PREFIX)/bin/luaserver

install-shared-files:
	$(MKDIR) $(LUASERVER_DIR)
	# make sure they don't exist, then recursive copy them!
	$(CP) -r ../inc    $(LUASERVER_DIR)/
	$(CP) -r ../libs   $(LUASERVER_DIR)/
	$(CP) -r ../lua    $(LUASERVER_DIR)/
	$(CP) -r ../static $(LUASERVER_DIR)/
	
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
	$(CP) luaserver.nginx /etc/nginx/sites-enabled/luaserver
	systemctl restart nginx.service

install: install-bin install-shared install-service install-nginx-site
