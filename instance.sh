#!/bin/bash

port=8080
instances=25
model="coroutine" # fork, pyrate or coroutine

pid_file=/var/run/luaserver/luaserver.pid

#if [ $(whoami) != "root" ]
#then
#	echo "error: you must be root to run this"
#	exit
#fi

start(){
	stop
	mkdir -p tmp/pids/
	nohup ./luaserver.lua --local --port=$port --threads=$instances --threads-model=$model --out-pid=$pid_file >> log.txt 2>&1 &
}

stop(){
	if [ -f $pid_file ]; then
		kill `cat $pid_file`
		rm $pid_file
	fi
}

case "$1" in
	start)
		start
		;;
	stop)
		stop
		;;
	install-deamon)
		echo "Installing deamon..."
		sudo cp `dirname $0`/luaserver_deamon /etc/init.d/luaserver
		;;
	*)
		echo "Usage: $0 {start|stop|install-deamon}"
		exit 1
		;;
esac

exit
