# mpv-user-input

This script aims to create a common API that other scripts can use to request text input from the user via the OSD.
The base text input code was taken from [mpv's console.lua](https://github.com/mpv-player/mpv/blob/7ca14d646c7e405f3fb1e44600e2a67fc4607238/player/lua/console.lua)
to keep to a standard behaviour.

User input requests are handled by a single script, which recieves requests via script-messages, and sends responses back to the original sender.
A standard interface function is provided in [get-user-input.lua](/get-user-input.lua), which can be loaded as a module, or simply pasted into another script.

The aim of this script is that it be seamless enough that it could be added to mpv player officially.

## Status
This script is still in the very early stages, it does not yet support multiple requests being made at once, and the formatting for the text input is still a clone of console.lua.
