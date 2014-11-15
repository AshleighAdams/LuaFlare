# Install LuaServer on Debian based distros
This simple guide will show you how to install LuaServer on a fresh install of Debian, compatible with Ubuntu/Mint.

### Install git, nginx, lua, and LuaServer's lua dependencies

```bash
sudo apt-get install git
sudo apt-get install nginx-full
sudo apt-get install lua5.2 lua-bitop lua-socket lua-sec lua-posix lua-filesystem lua-md5
```

### Remove nginx's default site

LuaServer uses Nginx as a reverse proxy on port 80 to 8080.  The default site listens on port 80, and therefore must be removed.

If you wish to keep your current Nginx configs, you can merge `/etc/nginx/sites-available/luaserver` with your own site config after install.

```bash
sudo rm /etc/nginx/sites-enabled/default
```

### Download and install LuaServer

```bash
git clone https://github.com/KateAdams/LuaServer
cd LuaServer/thirdparty/

### some arguments you may want for configuring: --prefix=/usr/local, --no-nginx (default if nginx is not installed), --lua=lua|luajit|lua5.1|lua5.2
./configure 
sudo make install
```
