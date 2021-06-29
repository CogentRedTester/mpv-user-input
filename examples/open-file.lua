--[[
    This is a demonstration script for mpv-user-input:
    https://github.com/CogentRedTester/mpv-user-input

    It allows users to enter file paths for mpv to open
    Ctrl+o replaces the current file with the entered link
    Ctrl+O appends the file to the playlist
]]

local mp = require "mp"

package.path = mp.command_native({"expand-path", "~~/script-modules/?.lua;"})..package.path
local uin = require "user-input-module"

local function loadfile(path, err, flag)
    if not path then return end
    mp.commandv("loadfile", path, flag)
end

mp.add_key_binding("Ctrl+o", "open-file-input", function()
    uin.get_user_input(loadfile, {
        request_text = "Enter path:",
        replace = true
    }, "replace")
end)

mp.add_key_binding("Ctrl+O", "append-file-input", function()
    uin.get_user_input(loadfile, {
        request_text = "Enter path to append to playlist:",
        replace = true
    }, "append-play")
end)