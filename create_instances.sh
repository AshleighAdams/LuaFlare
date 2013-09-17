#!/bin/bash

port=80
instances=10

if [ $(whoami) != "root" ]
then
	echo "error: you must be root to run this"
	exit
fi

./luaserver.lua --port=$port --threads=$instances