--[[
    The below code is a modified implementation of text input from mpv's console.lua:
    https://github.com/mpv-player/mpv/blob/7ca14d646c7e405f3fb1e44600e2a67fc4607238/player/lua/console.lua

    Modifications:
        Removed support for log messages, sending commands, tab complete, help commands
]]--

------------------------------START ORIGINAL MPV CODE-----------------------------------
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------

-- Copyright (C) 2019 the mpv developers
--
-- Permission to use, copy, modify, and/or distribute this software for any
-- purpose with or without fee is hereby granted, provided that the above
-- copyright notice and this permission notice appear in all copies.
--
-- THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
-- WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
-- MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
-- SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
-- WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION
-- OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
-- CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

local utils = require 'mp.utils'
local options = require 'mp.options'
local assdraw = require 'mp.assdraw'

-- Default options
local opts = {
    -- All drawing is scaled by this value, including the text borders and the
    -- cursor. Change it if you have a high-DPI display.
    scale = 1,
    -- Set the font used for the REPL and the console. This probably doesn't
    -- have to be a monospaced font.
    font = "",
    -- Set the font size used for the REPL and the console. This will be
    -- multiplied by "scale."
    font_size = 16,
}

function detect_platform()
    local o = {}
    -- Kind of a dumb way of detecting the platform but whatever
    if mp.get_property_native('options/vo-mmcss-profile', o) ~= o then
        return 'windows'
    elseif mp.get_property_native('options/macos-force-dedicated-gpu', o) ~= o then
        return 'macos'
    elseif os.getenv('WAYLAND_DISPLAY') then
        return 'wayland'
    end
    return 'x11'
end

-- Pick a better default font for Windows and macOS
local platform = detect_platform()
if platform == 'windows' then
    opts.font = 'Consolas'
elseif platform == 'macos' then
    opts.font = 'Menlo'
else
    opts.font = 'monospace'
end

-- Apply user-set options
options.read_options(opts)

local repl_active = false
local insert_mode = false
local pending_update = false
local line = ''
local cursor = 1
local history = {}
local history_pos = 1
local log_buffer = {}
local key_bindings = {}
local global_margin_y = 0

local update_timer = nil
update_timer = mp.add_periodic_timer(0.05, function()
    if pending_update then
        update()
    else
        update_timer:kill()
    end
end)
update_timer:kill()

utils.shared_script_property_observe("osc-margins", function(_, val)
    if val then
        -- formatted as "%f,%f,%f,%f" with left, right, top, bottom, each
        -- value being the border size as ratio of the window size (0.0-1.0)
        local vals = {}
        for v in string.gmatch(val, "[^,]+") do
            vals[#vals + 1] = tonumber(v)
        end
        global_margin_y = vals[4] -- bottom
    else
        global_margin_y = 0
    end
    update()
end)

-- Escape a string for verbatim display on the OSD
function ass_escape(str)
    -- There is no escape for '\' in ASS (I think?) but '\' is used verbatim if
    -- it isn't followed by a recognised character, so add a zero-width
    -- non-breaking space
    str = str:gsub('\\', '\\\239\187\191')
    str = str:gsub('{', '\\{')
    str = str:gsub('}', '\\}')
    -- Precede newlines with a ZWNBSP to prevent ASS's weird collapsing of
    -- consecutive newlines
    str = str:gsub('\n', '\239\187\191\\N')
    -- Turn leading spaces into hard spaces to prevent ASS from stripping them
    str = str:gsub('\\N ', '\\N\\h')
    str = str:gsub('^ ', '\\h')
    return str
end

-- Render the REPL and console as an ASS OSD
function update()
    pending_update = false

    local dpi_scale = mp.get_property_native("display-hidpi-scale", 1.0)

    dpi_scale = dpi_scale * opts.scale

    local screenx, screeny, aspect = mp.get_osd_size()
    screenx = screenx / dpi_scale
    screeny = screeny / dpi_scale

    -- Clear the OSD if the REPL is not active
    if not repl_active then
        mp.set_osd_ass(screenx, screeny, '')
        return
    end

    local ass = assdraw.ass_new()
    local style = '{\\r' ..
                  '\\1a&H00&\\3a&H00&\\4a&H99&' ..
                  '\\1c&Heeeeee&\\3c&H111111&\\4c&H000000&' ..
                  '\\fn' .. opts.font .. '\\fs' .. opts.font_size ..
                  '\\bord1\\xshad0\\yshad1\\fsp0\\q1}'
    -- Create the cursor glyph as an ASS drawing. ASS will draw the cursor
    -- inline with the surrounding text, but it sets the advance to the width
    -- of the drawing. So the cursor doesn't affect layout too much, make it as
    -- thin as possible and make it appear to be 1px wide by giving it 0.5px
    -- horizontal borders.
    local cheight = opts.font_size * 8
    local cglyph = '{\\r' ..
                   '\\1a&H44&\\3a&H44&\\4a&H99&' ..
                   '\\1c&Heeeeee&\\3c&Heeeeee&\\4c&H000000&' ..
                   '\\xbord0.5\\ybord0\\xshad0\\yshad1\\p4\\pbo24}' ..
                   'm 0 0 l 1 0 l 1 ' .. cheight .. ' l 0 ' .. cheight ..
                   '{\\p0}'
    local before_cur = ass_escape(line:sub(1, cursor - 1))
    local after_cur = ass_escape(line:sub(cursor))

    -- Render log messages as ASS. This will render at most screeny / font_size
    -- messages.
    local log_ass = ''
    local log_messages = #log_buffer
    local log_max_lines = math.ceil(screeny / opts.font_size)
    if log_max_lines < log_messages then
        log_messages = log_max_lines
    end
    for i = #log_buffer - log_messages + 1, #log_buffer do
        log_ass = log_ass .. style .. log_buffer[i].style .. ass_escape(log_buffer[i].text)
    end

    ass:new_event()
    ass:an(1)
    ass:pos(2, screeny - 2 - global_margin_y * screeny)
    ass:append(log_ass .. '\\N')
    ass:append(style .. '> ' .. before_cur)
    ass:append(cglyph)
    ass:append(style .. after_cur)

    -- Redraw the cursor with the REPL text invisible. This will make the
    -- cursor appear in front of the text.
    ass:new_event()
    ass:an(1)
    ass:pos(2, screeny - 2)
    ass:append(style .. '{\\alpha&HFF&}> ' .. before_cur)
    ass:append(cglyph)
    ass:append(style .. '{\\alpha&HFF&}' .. after_cur)

    mp.set_osd_ass(screenx, screeny, ass.text)
end

-- Set the REPL visibility ("enable", Esc)
function set_active(active)
    if active == repl_active then return end
    if active then
        repl_active = true
        insert_mode = false
        mp.enable_key_bindings('console-input', 'allow-hide-cursor+allow-vo-dragging')
        mp.enable_messages('terminal-default')
        define_key_bindings()
    else
        repl_active = false
        undefine_key_bindings()
        mp.enable_messages('silent:terminal-default')
        collectgarbage()
    end
    update()
end

-- Naive helper function to find the next UTF-8 character in 'str' after 'pos'
-- by skipping continuation bytes. Assumes 'str' contains valid UTF-8.
function next_utf8(str, pos)
    if pos > str:len() then return pos end
    repeat
        pos = pos + 1
    until pos > str:len() or str:byte(pos) < 0x80 or str:byte(pos) > 0xbf
    return pos
end

-- As above, but finds the previous UTF-8 charcter in 'str' before 'pos'
function prev_utf8(str, pos)
    if pos <= 1 then return pos end
    repeat
        pos = pos - 1
    until pos <= 1 or str:byte(pos) < 0x80 or str:byte(pos) > 0xbf
    return pos
end

-- Insert a character at the current cursor position (any_unicode, Shift+Enter)
function handle_char_input(c)
    if insert_mode then
        line = line:sub(1, cursor - 1) .. c .. line:sub(next_utf8(line, cursor))
    else
        line = line:sub(1, cursor - 1) .. c .. line:sub(cursor)
    end
    cursor = cursor + #c
    update()
end

-- Remove the character behind the cursor (Backspace)
function handle_backspace()
    if cursor <= 1 then return end
    local prev = prev_utf8(line, cursor)
    line = line:sub(1, prev - 1) .. line:sub(cursor)
    cursor = prev
    update()
end

-- Remove the character in front of the cursor (Del)
function handle_del()
    if cursor > line:len() then return end
    line = line:sub(1, cursor - 1) .. line:sub(next_utf8(line, cursor))
    update()
end

-- Toggle insert mode (Ins)
function handle_ins()
    insert_mode = not insert_mode
end

-- Move the cursor to the next character (Right)
function next_char(amount)
    cursor = next_utf8(line, cursor)
    update()
end

-- Move the cursor to the previous character (Left)
function prev_char(amount)
    cursor = prev_utf8(line, cursor)
    update()
end

-- Clear the current line (Ctrl+C)
function clear()
    line = ''
    cursor = 1
    insert_mode = false
    history_pos = #history + 1
    update()
end

-- Close the REPL if the current line is empty, otherwise do nothing (Ctrl+D)
function maybe_exit()
    if line == '' then
        set_active(false)
    end
end

-- Run the current command and clear the line (Enter)
function handle_enter()
    if line == '' then
        return
    end

    -- NEW CODE HERE

    clear()
end

-- Move to the start of the current word, or if already at the start, the start
-- of the previous word. (Ctrl+Left)
function prev_word()
    -- This is basically the same as next_word() but backwards, so reverse the
    -- string in order to do a "backwards" find. This wouldn't be as annoying
    -- to do if Lua didn't insist on 1-based indexing.
    cursor = line:len() - select(2, line:reverse():find('%s*[^%s]*', line:len() - cursor + 2)) + 1
    update()
end

-- Move to the end of the current word, or if already at the end, the end of
-- the next word. (Ctrl+Right)
function next_word()
    cursor = select(2, line:find('%s*[^%s]*', cursor)) + 1
    update()
end

-- Move the cursor to the beginning of the line (HOME)
function go_home()
    cursor = 1
    update()
end

-- Move the cursor to the end of the line (END)
function go_end()
    cursor = line:len() + 1
    update()
end

-- Delete from the cursor to the end of the word (Ctrl+W)
function del_word()
    local before_cur = line:sub(1, cursor - 1)
    local after_cur = line:sub(cursor)

    before_cur = before_cur:gsub('[^%s]+%s*$', '', 1)
    line = before_cur .. after_cur
    cursor = before_cur:len() + 1
    update()
end

-- Delete from the cursor to the end of the line (Ctrl+K)
function del_to_eol()
    line = line:sub(1, cursor - 1)
    update()
end

-- Delete from the cursor back to the start of the line (Ctrl+U)
function del_to_start()
    line = line:sub(cursor)
    cursor = 1
    update()
end

-- Returns a string of UTF-8 text from the clipboard (or the primary selection)
function get_clipboard(clip)
    if platform == 'x11' then
        local res = utils.subprocess({
            args = { 'xclip', '-selection', clip and 'clipboard' or 'primary', '-out' },
            playback_only = false,
        })
        if not res.error then
            return res.stdout
        end
    elseif platform == 'wayland' then
        local res = utils.subprocess({
            args = { 'wl-paste', clip and '-n' or  '-np' },
            playback_only = false,
        })
        if not res.error then
            return res.stdout
        end
    elseif platform == 'windows' then
        local res = utils.subprocess({
            args = { 'powershell', '-NoProfile', '-Command', [[& {
                Trap {
                    Write-Error -ErrorRecord $_
                    Exit 1
                }

                $clip = ""
                if (Get-Command "Get-Clipboard" -errorAction SilentlyContinue) {
                    $clip = Get-Clipboard -Raw -Format Text -TextFormatType UnicodeText
                } else {
                    Add-Type -AssemblyName PresentationCore
                    $clip = [Windows.Clipboard]::GetText()
                }

                $clip = $clip -Replace "`r",""
                $u8clip = [System.Text.Encoding]::UTF8.GetBytes($clip)
                [Console]::OpenStandardOutput().Write($u8clip, 0, $u8clip.Length)
            }]] },
            playback_only = false,
        })
        if not res.error then
            return res.stdout
        end
    elseif platform == 'macos' then
        local res = utils.subprocess({
            args = { 'pbpaste' },
            playback_only = false,
        })
        if not res.error then
            return res.stdout
        end
    end
    return ''
end

-- Paste text from the window-system's clipboard. 'clip' determines whether the
-- clipboard or the primary selection buffer is used (on X11 and Wayland only.)
function paste(clip)
    local text = get_clipboard(clip)
    local before_cur = line:sub(1, cursor - 1)
    local after_cur = line:sub(cursor)
    line = before_cur .. text .. after_cur
    cursor = cursor + text:len()
    update()
end

-- List of input bindings. This is a weird mashup between common GUI text-input
-- bindings and readline bindings.
function get_bindings()
    local bindings = {
        { 'esc',         function() set_active(false) end       },
        { 'enter',       handle_enter                           },
        { 'kp_enter',    handle_enter                           },
        { 'shift+enter', function() handle_char_input('\n') end },
        { 'bs',          handle_backspace                       },
        { 'shift+bs',    handle_backspace                       },
        { 'del',         handle_del                             },
        { 'shift+del',   handle_del                             },
        { 'ins',         handle_ins                             },
        { 'shift+ins',   function() paste(false) end            },
        { 'mbtn_mid',    function() paste(false) end            },
        { 'left',        function() prev_char() end             },
        { 'right',       function() next_char() end             },
        { 'wheel_left',  function() end                         },
        { 'wheel_right', function() end                         },
        { 'ctrl+left',   prev_word                              },
        { 'ctrl+right',  next_word                              },
        { 'home',        go_home                                },
        { 'end',         go_end                                 },
        { 'ctrl+c',      clear                                  },
        { 'ctrl+d',      maybe_exit                             },
        { 'ctrl+k',      del_to_eol                             },
        { 'ctrl+u',      del_to_start                           },
        { 'ctrl+v',      function() paste(true) end             },
        { 'meta+v',      function() paste(true) end             },
        { 'ctrl+w',      del_word                               },
        { 'kp_dec',      function() handle_char_input('.') end  },
    }

    for i = 0, 9 do
        bindings[#bindings + 1] =
            {'kp' .. i, function() handle_char_input('' .. i) end}
    end

    return bindings
end

local function text_input(info)
    if info.key_text and (info.event == "press" or info.event == "down"
                          or info.event == "repeat")
    then
        handle_char_input(info.key_text)
    end
end

function define_key_bindings()
    if #key_bindings > 0 then
        return
    end
    for _, bind in ipairs(get_bindings()) do
        -- Generate arbitrary name for removing the bindings later.
        local name = "_console_" .. (#key_bindings + 1)
        key_bindings[#key_bindings + 1] = name
        mp.add_forced_key_binding(bind[1], name, bind[2], {repeatable = true})
    end
    mp.add_forced_key_binding("any_unicode", "_console_text", text_input,
        {repeatable = true, complex = true})
    key_bindings[#key_bindings + 1] = "_console_text"
end

function undefine_key_bindings()
    for _, name in ipairs(key_bindings) do
        mp.remove_key_binding(name)
    end
    key_bindings = {}
end

-- Redraw the REPL when the OSD size changes. This is needed because the
-- PlayRes of the OSD will need to be adjusted.
mp.observe_property('osd-width', 'native', update)
mp.observe_property('osd-height', 'native', update)
mp.observe_property('display-hidpi-scale', 'native', update)

----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------
-------------------------------END ORIGINAL MPV CODE------------------------------------

--temporary keybind for debugging purposes
mp.add_key_binding("Ctrl+i", "user-input", function() set_active(true) end)