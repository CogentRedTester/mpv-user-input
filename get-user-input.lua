--[[
    This is a module designed to interface with mpv-user-input
    https://github.com/CogentRedTester/mpv-user-input

    Loading this script as a module will return a function that formats a user input request.
    Alternatively, developers can just paste this function directly into their script.
]]

local mp = require 'mp'
local utils = require 'mp.utils'

local counter = 1
local function get_user_input(funct, options)
    local name = mp.get_script_name()
    options = options or {}
    options.id = options.id or name
    options.text = options.text or (name.." is requesting user input:")

    local response_string = name.."/__user_input_request/"..counter
    options.response = response_string

    options = utils.format_json(options)
    if not options then error("table cannot be converted to json string") ; return end

    -- create a callback for user-input to respond to
    counter = counter + 1
    mp.register_script_message(response_string, function(response)
        mp.unregister_script_message(response_string)
        funct(response)
    end)

    mp.commandv("script-message-to", "user_input", "request-user-input", options)
end

return get_user_input