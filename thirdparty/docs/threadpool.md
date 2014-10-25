# LuaServer threadpool libary

`local threadpool = require("luaserver.threadpool")`

## `pool threadpool.create(number threads, function func)`

Creates and returns a threadpool.

`func(obj)` is called for each `enqueue()`ed object.

## `pool:enqueue(any object)`

Adds an object to the queue.

## *`object pool:dequeue()`*

Removes and returns the first item from the queue.

## `pool:done()`

Returns whether or not the queue is empty.

## `pool:step()`

Resume all threads.
