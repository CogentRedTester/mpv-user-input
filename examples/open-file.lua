--[[
    This is a demonstration script for mpv-user-input:
    https://github.com/CogentRedTester/mpv-user-input

    It allows users to enter file paths for mpv to open
    Ctrl+o replaces the current file with the entered link
    Ctrl+O appends the file to the playlist
]]

local mp = require "mp"

package.path = mp.command_native({"expand-path", "~~/script-modules/?.lua;"})..package.path
local ui = require "user-input-module"
local get_user_input = ui.get_user_input


local function loadfile(path, flag)
    if not path then return end
    mp.commandv("loadfile", path, flag)
end

mp.add_key_binding("Ctrl+o", "open-file-input", function()
    get_user_input(function(input)
        loadfile(input, "replace")
    end, {
        text = "[open-file] Enter path to open:",
        replace = true
    })
end)

mp.add_key_binding("Ctrl+O", "append-file-input", function()
    get_user_input(function(input)
        loadfile(input, "append-play")
    end, {
        text = "[open-file] Enter path to append to playlist:",
        replace = true
    })
end)