#!/bin/bash

port=8080
instances=25
model="coroutine" # fork, pyrate or coroutine

#if [ $(whoami) != "root" ]
#then
#	echo "error: you must be root to run this"
#	exit
#fi

./luaserver.lua --local --port=$port --threads=$instances --threads-model=$model | tee -a log.txt
