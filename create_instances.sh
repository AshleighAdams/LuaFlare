#!/bin/bash

port=80
instances=10

if [ $(whoami) != "root" ]
then
	echo "error: you must be root to run this"
	exit
fi

for (( i=1; i < $instances; i++ ))
do
	echo "staring server instance $i"
	./luaserver.lua --port=$port --instance=$i &
done

echo "staring server instance $instances"
./luaserver.lua --port=$port --instance=$instances

# kill the instances we created
trap "kill 0" SIGINT SIGTERM EXIT