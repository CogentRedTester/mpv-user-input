--[[
    This is a module designed to interface with mpv-user-input
    https://github.com/CogentRedTester/mpv-user-input

    Loading this script as a module will return a function that formats a user input request.
    Alternatively, developers can just paste this function directly into their script.
]]

local mp = require 'mp'

local name = mp.get_script_name()
local counter = 1
local function get_user_input(funct, options)
    options = options or {}
    options.id = name .. '/' .. (options.id or "")
    options.request_text = options.request_text or options.text or (name.." is requesting user input:")

    local response_string = name.."/__user_input_request/"..counter
    counter = counter + 1

    -- create a callback for user-input to respond to
    mp.register_script_message(response_string, function(input, err)
        mp.unregister_script_message(response_string)
        funct(err == "" and input or nil, err)
    end)

    mp.commandv("script-message-to", "user_input", "request-user-input",
        response_string, options.id, options.request_text, options.default_input or "", options.queueable and "1" or "", options.replace and "1" or ""
    )
end

local function cancel_user_input(id)
    id = name .. '/' .. (id or "")
    mp.commandv("script-message-to", "user_input", "cancel-user-input", id)
end

return { get_user_input = get_user_input, cancel_user_input = cancel_user_input}