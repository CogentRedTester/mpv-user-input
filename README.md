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

## Interface Functions

Note: this API is still in its early stages, so these functions may change.

### `get_user_input(fn [,options])`

Requests user input and calls `fn` when this script sends a response.
The first argument will be the input string the user entered, the second argument will be an error string if the input is `nil`.

The following error codes currently exist:

    exitted         the user closed the input instead of pressing Enter
    already_queued  a request with the specified id was already in the queue
    replaced        the request was replaced with a newer request
    cancelled       a script cancelled the request

#### options

Options is a table of values and flags which can be used to control the behaviour of user-input. The function will preset some options if they are left blank.
The following options are currently available:

    id              a string id used for storing input history and detecting duplicate requests (default: mp.get_script_name())
    request_text    a string to print above the input box - use it to describe the input request
    default_input   text to pre-enter into the input
    queueable       allow request if another request with the same id is already queued
    replace         replace the first existing request with the same id - otherwise add to the back like normal - overrides queueable

The function prepends the script name to any id to avoid conflicts, but the actual script has no way to determining where the requests come from,
so make sure that the function is used.

Also note that the `queueable` and `replace` flags apply to the incoming requests, not requests that already exist in the queue.

### `cancel_user_input([id])`

Removes all input requests with a matching string id.
If no id is provided, then the script's name - as returned by `mp.get_script_name()` - will be used.

## Examples

The [examples](/examples) folder contains some scripts that make user of the API.
