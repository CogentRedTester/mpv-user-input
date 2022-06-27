--[[
    This is a module designed to interface with mpv-user-input
    https://github.com/CogentRedTester/mpv-user-input

    Loading this script as a module will return a table with two functions to format
    requests to get and cancel user-input requests. See the README for details.

    Alternatively, developers can just paste these functions directly into their script,
    however this is not recommended as there is no guarantee that the formatting of
    these requests will remain the same for future versions of user-input.
]]

local API_VERSION = "0.1.0"

local mp = require 'mp'
local utils = require 'mp.utils'

local mod = {}
local name = mp.get_script_name()

local function pack(...)
    local t = {...}
    t.n = select("#", ...)
    return t
end

local counter = 1
local function get_response_string()
    local str = "__user_input_module_response/"..counter
    counter = counter + 1
    return str
end

local function ontab_callback(cb)
    if not cb then return nil end
    local callback = get_response_string()

    mp.register_script_message(callback, function(t)
        t = utils.parse_json(t)
        local response = t.response
        t.response = nil

        local text, cursor = cb(t)
        if not text then
            mp.commandv("script-message-to", "user_input", response)
            return
        end

        local res = { text = text, cursor = cursor }
        mp.commandv("script-message-to", "user_input", response, (utils.format_json(res)))
    end)
    return callback
end

-- sends a request to ask the user for input using formatted options provided
-- creates a script message to recieve the response and call fn
function mod.get_user_input(fn, options, ...)
    options = options or {}
    local response_string = get_response_string()

    local passthrough_args = pack(...)

    -- create a callback for user-input to respond to
    mp.register_script_message(response_string, function(response)
        mp.unregister_script_message(response_string)

        response = utils.parse_json(response)
        fn(response.line, response.err, unpack(passthrough_args, 1, passthrough_args.n))
    end)

    -- send the input command
    mp.commandv("script-message-to", "user_input", "request-user-input", (utils.format_json({
        version = API_VERSION,
        id = name..'/'..(options.id or ""),
        source = name,
        response = response_string,
        request_text = ("[%s] %s"):format(options.source or name, options.request_text or options.text or "requesting user input:"),
        default_input = options.default_input,
        cursor_pos = options.cursor_pos,
        queueable = options.queueable and true,
        ontab = ontab_callback(options.ontab)
    })))
end

-- sends a request to cancel all input requests with the given id
function mod.cancel_user_input(id)
    id = name .. '/' .. (id or "")
    mp.commandv("script-message-to", "user_input", "cancel-user-input", id)
end

return mod