#!/bin/bash

action=$1
pidfile="$2"

cd `dirname $0`
[ -f ./cmdline ] && args="`cat ./cmdline`"

start(){
	nohup ./luaserver.lua --out-pid=$pidfile $args >> log.txt 2>&1 &
	exit 0
}

stop(){
	echo "notimp"
}

case "$action" in
	start)
		start
		;;
	stop)
		stop
		;;
	install-daemon)
		echo "Installing daemon..."
		sudo cp `dirname $0`/luaserver_daemon /etc/init.d/luaserver
		sudo update-rc.d luaserver defaults # so it boots on startup
		;;
	*)
		echo "Usage: $0 {start|stop|install-daemon}"
		exit 1
		;;
esac

exit
