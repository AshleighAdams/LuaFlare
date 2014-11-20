# Install LuaFlare on Debian based distros
This simple guide will show you how to install LuaFlare on a fresh install of Debian, compatible with Ubuntu/Mint.

### Install git, nginx, lua, and LuaFlare's lua dependencies

    sudo apt-get install git
    sudo apt-get install nginx-full
    sudo apt-get install lua5.2 lua-bitop lua-socket lua-sec lua-posix lua-filesystem lua-md5

### Remove nginx's default site

LuaFlare uses Nginx as a reverse proxy on port 80 to 8080.  The default site listens on port 80, and therefore must be removed.

If you wish to keep your current Nginx configs, you can merge `/etc/nginx/sites-available/luaflare` with your own site config after install.

    sudo rm /etc/nginx/sites-enabled/default

### Download and install LuaFlare

    git clone https://github.com/KateAdams/LuaFlare
    cd LuaFlare/thirdparty/
    #some arguments you may want for configuring: --prefix=/usr/local, --no-nginx (default if nginx is not installed), --lua=lua|luajit|lua5.1|lua5.2
    ./configure 
    sudo make install

### Generate SSL keys

You may want to provide your own keys, or generate your own (with no CA).

    cd /etc/luaflare/keys/
    ./generatekey.sh
