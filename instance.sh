#!/bin/bash

port=8080
instances=25
model="coroutine" # fork, pyrate or coroutine

#if [ $(whoami) != "root" ]
#then
#	echo "error: you must be root to run this"
#	exit
#fi

start(){
	stop
	mkdir -p tmp/pids/
	./luaserver.lua --local --port=$port --threads=$instances --threads-model=$model --out-pid=tmp/pids/luaserver.pid >> log.txt
}

stop(){
	if [ -f tmp/pids/luaserver.pid ]; then
		kill `cat tmp/pids/luaserver.pid`
		rm tmp/pids/luaserver.pid
	fi
}

case "$1" in
  start)
        start
        ;;
  stop)
        stop
        ;;
  *)
        echo "Usage: $0 {start|stop}"
        exit 1
        ;;
esac

exit
