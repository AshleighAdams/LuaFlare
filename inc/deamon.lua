
local posix = require("posix")

local curdir = posix.getcwd()
print("enter user:")
local user = io.stdin:read("*l")

if ({os.capture("ln -s " .. curdir .. " /usr/local/bin/luaserver")})[2] ~= 0 then
	print("failed to create system link")
end

local code = [[
#!/bin/sh
 
### BEGIN INIT INFO
# Provides:          luaserver
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: LuaServer deamon
# Description:       LuaServer deamon
### END INIT INFO

# Change the next 3 lines to suit where you install your script and what you want to call it
DIR=/usr/local/bin/luaserver
DAEMON=$DIR/create_instance.lua
DAEMON_NAME=luaserver
 
# This next line determines what user the script runs as.
# Root generally not recommended but necessary if you are using the Raspberry Pi GPIO from Python.
DAEMON_USER=]] .. user .. [[
 
# The process ID of the script when it runs is stored here:
PIDFILE=/var/run/$DAEMON_NAME.pid
 
. /lib/lsb/init-functions
 
do_start () {
    log_daemon_msg "Starting system $DAEMON_NAME daemon"
    start-stop-daemon --start --background --pidfile $PIDFILE --make-pidfile --user $DAEMON_USER --startas $DAEMON
    log_end_msg $?
}
do_stop () {
    log_daemon_msg "Stopping system $DAEMON_NAME daemon"
    start-stop-daemon --stop --pidfile $PIDFILE --retry 10
    log_end_msg $?
}
 
case "$1" in
 
    start|stop)
        do_${1}
        ;;
 
    restart|reload|force-reload)
        do_stop
        do_start
        ;;
 
    status)
        status_of_proc "$DAEMON_NAME" "$DAEMON" && exit 0 || exit $?
        ;;
    *)
        echo "Usage: /etc/init.d/$DEAMON_NAME {start|stop|restart|status}"
        exit 1
        ;;
 
esac
exit 0
]]

local file = assert(io.open("/etc/init.d/luaserver", "w"))
file:write(code)
file:close()

if ({os.capture("chmod +x /etc/init.d/luaserver")})[2] ~= 0 then
	return print("failed to set executable bit on /etc/init.d/luaserver")
end