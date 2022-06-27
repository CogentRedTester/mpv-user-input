# mpv-user-input

This script aims to create a common API that other scripts can use to request text input from the user via the OSD.
This script was built from [mpv's console.lua](https://github.com/mpv-player/mpv/blob/7ca14d646c7e405f3fb1e44600e2a67fc4607238/player/lua/console.lua).
The logging, commands, and tab completion have been removed, leaving just the text input and history code.
As a result this script's text input has almost identical behaviour to console.lua.

Around the original code is a system to recieve input requests via script messages, and respond with the users input, and an error message if the request was somehow terminated.
The script utilises a queue system to handle multiple requests at once, and there are various option flags to control how to handle multiple requests from the same source.

Usage of this API requires that standard interface functions be used to request and cancel input requests, these functions are packaged into [user-input-module.lua](/user-input-module.lua), which can be loaded as a module, or simply pasted into another script.
If a script does choose to load the module, then I recommend it be loaded from `~~/script-modules` rather than `~~/scripts`.

The aim of this script is that it be seamless enough that it could be added to mpv player officially.

## Installation

**If you've been directed here by another script that requires this API follow these instructions unless told otherwise.**

Place [user-input.lua](user-input.lua) inside the `~~/scripts/` directory, and place [user-input-module.lua](user-input-module.lua) inside the `~~/script-modules/` directory.
Create these directories if they do not exist. `~~/` represents the mpv config directory.

### Advanced

What is important is that `user-input.lua` is loaded as a script my mpv, which can be done from anywhere using the `--script` option.
Meanwhile, `user-input-module.lua` needs to be in one of the lua package paths; scripts that use this API are recommended to use `~~/script-modules/`, but you can set any directory using the `LUA_PATH` environment variable.

### Developers

If you use the recommended `~~/script-modules/` directory then load this addon with the following code:

```lua
package.path = mp.command_native({"expand-path", "~~/script-modules/?.lua;"})..package.path
local input = require "user-input-module"
```

## Interface Functions - v0.1.0

Note: this API is still in its early stages, so these functions may change.

### `get_user_input(fn [, options [, ...]])`

Requests input from the user and returns a request table.

```lua
input.get_user_input(print) -- prints the user input plus the error code
```

`fn` is called when user-input sends a response, the first argument will be the input string the user entered,
the second argument will be an error string if the input is `nil`.
Any additional arguments sent after the options table will be sent to fn as additional arguments after the error string.

The following error codes currently exist:

```properties
    exited          the user closed the input instead of pressing Enter
    already_queued  a request with the specified id was already in the queue
    cancelled       the request was cancelled
    replaced        request was replaced
```

If the request throws an error for whatever reason then that Lua error message will be returned instead.
Those error messages are undefined and could change at any time.

#### options

Options is an optional table of values and flags which can be used to control the behaviour of user-input. The function will preset some options if they are left blank.
The following options are currently available:

| name          | type    | default                   | description                                                                                                       |
|---------------|---------|---------------------------|-------------------------------------------------------------------------------------------------------------------|
| id            | string  | mp.get_script_name()..`/` | used for storing input history and detecting duplicate requests                                                   |
| source        | string  | mp.get_script_name()      | used to show the source of the request in square brackets                                                         |
| request_text  | string  | `requesting user input:`  | printed above the input box - use it to describe the input request                                                |
| default_input | string  |                           | text to pre-enter into the input                                                                                  |
| cursor_pos    | number  | 1                         | the numerical position to place the cursor - for use with the default_input field                                 |
| queueable     | boolean | false                     | allows request to be queued even if there is already one queued with the same id                                  |
| replace       | boolean | false                     | replace all queued requests with the same id with the new request                                                 |

The function prepends the script name to any id to avoid conflicts, but the actual script has no way to determining where the requests come from,
so make sure that the function is used.

Here is an example for printing only a sucessful input:

```lua
input.get_user_input(function(line, err)
        if line then print(line) end
    end, { request_text = "print text:" })
```

#### request table

The request table returned by `get_user_input` can be used to modify the behaviour of an existing request.
The defined fields are:

| name          | type    | description                                                                                                       |
|---------------|---------|-------------------------------------------------------------------------------------------------------------------|
| callback      | function| the callback function - same as `fn` passed to `get_user_input()` - can be set to a different function to modify the callback |
| passthrough_args | table| an array of extra arguments to pass to the callback - cannot be `nil`                                             |
| pending       | boolean | true if the request is still pending, false if the request is completed                                           |
| cancel        | method  | cancels the request - unlike `cancel_user_input()` this does not cancel all requests with a matching id           |
| update        | method  | takes an options table and updates the request - maintains the original request unlike the `replace` flag - not all options can be changed |

A method is referring to a function that is called with Lua's method syntax:

```lua
local request = input.get_user_input(print)
request:update{
    request_text = "hello world:"
}
request:cancel()
```

### `cancel_user_input([id])`

Removes all input requests with a matching string id.
If no id is provided, then the default id for `get_user_input()` will be used.

The cancellation happens asynchronously.

### `get_user_input_co([options [, co_resume]])`

This is a wrapper function around `get_user_input()` that uses [coroutines](https://www.lua.org/manual/5.1/manual.html#2.11)
to make the input request behave synchronously. It returns `line, err`, as would
normally be passed to the callback function.

This function will yield the current coroutine and resume once the input
response has been received. If the coroutine is forcibly resumed by the user then
it will send a cancellation request to `user-input` and will return `nil, 'cancelled'`.
The request object is passed to the yield function.

If a function is passed as co_resume then custom resume behaviour can be setup instead
of the default `coroutine.resume`.
This function is passed `uid, line, err` where `uid` is a unique variable that needs to be
passed to the resume. The functions created by `coroutine.wrap` will work.

## Examples

The [examples](/examples) folder contains some scripts that make user of the API.
