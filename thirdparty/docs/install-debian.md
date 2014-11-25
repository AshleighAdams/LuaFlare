# Install LuaFlare on Debian based distros
This simple guide will show you how to install LuaFlare on a fresh install of Debian, compatible with Ubuntu/Mint.

## Either install via apt-get (my repo @ kateadams.eu)

May not be bleeding edge, but is updated via apt-get.

### sources.list

Open `/etc/apt/sources.list.d/kateadams` as a root, and set it's contents to:

    deb http://kateadams.eu/ debian/
    deb-src http://kateadams.eu/ debian/

### apt keys

	gpg --recv-keys ED672012
	gpg -a --export ED672012 | sudo apt-key add -

### install

    sudo apt-get update
    sudo apt-get install luaflare luaflare-service luaflare-reverseproxy-nginx

Please continue to [Enable the Nginx site](#enable-the-nginx-site).

## Or install via git (Makefile)

Bleeding edge, must be updated manually.

### Install git, nginx, lua, and LuaFlare's lua dependencies

    sudo apt-get install git
    sudo apt-get install nginx-full
    sudo apt-get install lua5.2 lua-bitop lua-socket lua-sec lua-posix lua-filesystem lua-md5

### Download and install LuaFlare

    git clone https://github.com/KateAdams/LuaFlare
    cd LuaFlare/thirdparty/
    #some arguments you may want for configuring: --prefix=/usr/local, --no-nginx (default if nginx is not installed), --lua=lua|luajit|lua5.1|lua5.2
    ./configure 
    sudo make install

## Enable the Nginx site

### Remove nginx's default site

LuaFlare uses Nginx as a reverse proxy on port 80 to 8080.  The default site listens on port 80, and therefore must be removed.

If you wish to keep your current Nginx configs, you can merge `/etc/nginx/sites-available/luaflare` with your own site config after install.

    sudo rm /etc/nginx/sites-enabled/default

#### Enabling LuaFlare's site

    sudo ln -s /etc/nginx/sites-available/luaflare /etc/nginx/sites-enabled/luaflare


## Others/Help

### Alternate method to get the keys for apt

    curl kateadams.eu/debian/key | sudo apt-key add -
