#!/bin/bash

function scan()
{
	FILES=`find . | grep -i luaflare`

	for f in $FILES; do
		newname=`echo "$f" | sed "s|LuaFlare|LuaFlare|g" | sed "s|luaflare|luaflare|g"`
		mv "$f" "$newname"
		return 0
	done
	
	return 1
}

while scan; do
	scan
done
