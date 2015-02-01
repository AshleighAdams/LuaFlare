# LuaFlare scheduler library

`local scheduler = require("luaflare.scheduler")`

Allows you to periodically run tasks.

## `scheduler.newtask(string name, function func)`

Creates a new scheduled task.  Return from `func` to exit the task, and yield (`coroutine.yield()`) the number of seconds you want to wait.

## `scheduler.run()`

Resumes all scheduled tasks.  Any tasks that take longer than half a second to either yield or return results in a warning, as during the time your scheduled task is running, LuaFlare may be hung.

To yield from a task, you should use [`scheduler.sleep()`](#schedulersleepnumber-seconds), rather than `coroutine.yield()`.

## `number scheduler.idletime()`

Returns the number of seconds until the next scheduled task is to be resumed; `-1` if complete.

## `scheduler.sleep(number seconds)`

Tell the scheduler to resume this thread in n seconds.

## `boolean scheduler.done()`

Returns true if all tasks are complete.
