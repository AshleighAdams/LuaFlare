#!/bin/bash

action=$1
pid_file="$2"
shift 2
args="$@"

# $1 ... $n are now the arguments, so $@ will work

start(){
	stop
	nohup ./luaserver.lua --out-pid=$pid_file $args >> log.txt 2>&1 &
}

stop(){
	if [ -f $pid_file ]; then
		kill `cat $pid_file`
		rm $pid_file
	fi
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
