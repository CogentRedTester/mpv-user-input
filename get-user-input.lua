--[[
    This is a module designed to interface with mpv-user-input
    https://github.com/CogentRedTester/mpv-user-input

    Loading this script as a module will return a function that formats a user input request.
    Alternatively, developers can just paste this function directly into their script.
]]

local mp = require 'mp'
local utils = require 'mp.utils'

local counter = 1
local function get_user_input(funct, options, ...)
    if options then
        options.passthrough = {...}
        options = utils.format_json(options)
        if not options then error("table cannot be converted to json string") ; return end
    end

    -- create a callback for user-input to respond to
    local response_string = mp.get_script_name().."/__user_input_request/"..counter
    counter = counter + 1
    mp.register_script_message(response_string, function(response, ...)
        mp.unregister_script_message(response_string)
        funct(response, ...)
    end)

    mp.commandv("script-message-to", "user_input", "request-user-input", options, response_string)
end

return get_user_input