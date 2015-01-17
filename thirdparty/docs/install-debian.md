# Install LuaFlare on Debian based distros

This simple guide will show you how to install LuaFlare on a fresh install of Debian 7, compatible with Ubuntu 12.04 and up.

The sysvinit service uses a newer syntax, so if your system uses sysvinit, the dependency `sysvinit-utils (>= 2.88dsf-50)` must be satisfiable;
in Debian, this is satisfied at 7 (Jessie), and with Ubuntu, 15.04 (Vivid).
By default, Debian (>= 7) uses systemd by default, and Ubuntu (>= 12.04) uses upstart.

In Ubuntu 14.04 and older, luaflare-service is not installable
as the dependency `init-system-helpers (>= 1.18~)` is not satisfiable
(this is automatically added via `dh_installinit`).
You may have to install the service files yourself by checking out the source
(`apt source luaflare`), running the configure script, and then
copying `thirdparty/luaflare.upstart.post` to `/etc/init/luaflare.conf`.

## Either install via APT (my repo @ kateadams.eu/debian/)

May not be bleeding edge, but is updated via APT.

### sources.list

Open `/etc/apt/sources.list.d/kateadams.list` as a root, and set it's contents to:

    deb http://kateadams.eu/ debian/
    deb-src http://kateadams.eu/ debian/

### apt keys

    sudo apt-key adv --keyserver keys.gnupg.net --recv 0B7BD0AD

### install

    sudo apt update
    sudo apt install luaflare

## Or install via git (Makefile)

Bleeding edge, must be updated manually.

### Install git, nginx, lua, and LuaFlare's lua dependencies

    sudo apt install git
    sudo apt install nginx-full
    sudo apt install lua5.2 lua-bitop lua-socket lua-posix lua-filesystem lua-md5

### Download and install LuaFlare

    git clone https://github.com/KateAdams/LuaFlare
    cd LuaFlare/thirdparty/
    #some arguments you may want for configuring: --prefix=/usr/local, --no-nginx (default if nginx is not installed), --lua=lua|luajit|lua5.1|lua5.2
    ./configure 
    sudo make install

### Enable the Nginx site

### Remove nginx's default site

LuaFlare uses Nginx as a reverse proxy on port 80 to 8080.  The default site listens on port 80, and therefore must be removed.

If you wish to keep your current Nginx configs, you can merge `/etc/nginx/sites-available/luaflare` with your own site config after install.

    sudo rm /etc/nginx/sites-enabled/default

#### Enabling LuaFlare's site

    sudo ln -s /etc/nginx/sites-available/luaflare /etc/nginx/sites-enabled/luaflare


## Others/Help

### Old method to import keys from gpg

	gpg --recv-keys 0B7BD0AD
	gpg -a --export 0B7BD0AD | sudo apt-key add -

### Alternate method to get the keys for apt

    curl kateadams.eu/debian/key | sudo apt-key add -
