local M = {}

local ns = vim.api.nvim_create_namespace('houdini')
local timer = vim.loop.new_timer()

local combinations = {}
local last_char = ''
local last_mode = ''
local last_tick = 0
local last_cursor_pos = { 0, 0 }
local excluded_filetypes_set = {}

local ignore_key = vim.api.nvim_replace_termcodes('<Ignore>', true, true, true)

---@alias HoudiniEscapeFunction fun(char_one: string, char_two: string, pos: table<number,number>, tick: number): string

---@class HoudiniConfiguration
---@field mappings table<string>? A list of mappings that should trigger the escape sequences
---@field timeout number? The time in milliseconds after which the escape sequence should be triggered
---@field check_modified boolean? Whether the buffer content should be checked for changes AFTER triggering the escape sequence to suppress the modified state in case no text was actually modified
---@field escape_sequences table<string,string|false|HoudiniEscapeFunction>? A table of escape sequences for different modes

---Escape modes that might switch to another mode in the process and undo changes that have been done by the key presses of the escape sequence
---Also restores the cursor position after the escape sequence (`<ESC>`) has been typed
---@type HoudiniEscapeFunction
---@diagnostic disable-next-line: duplicate-doc-param
---@param _ string Char one (ignore)
---@diagnostic disable-next-line: duplicate-doc-param
---@param _ string Char two (ignore)
---@param pos table<number,number> The last cursor position
---@param tick number The last value of the `changedtick` variable
---@return string esc_sequence The escape sequence to be used
function M.escape_and_undo(_, _, pos, tick)
    -- depending on the situation the changedtick value might be updated AFTER the escape sequence has been typed
    -- therefore we're using `vim.schedule` to check again for additional changes
    vim.schedule(function()
        if vim.b.changedtick > tick then
            vim.cmd.undo { bang = true }
        end
        vim.api.nvim_win_set_cursor(0, pos)
    end)

    if vim.b.changedtick > tick then
        vim.cmd.undo { bang = true }
        tick = vim.b.changedtick
    end

    return '<ESC>'
end

---@type HoudiniConfiguration
local defaults = {
    mappings = { 'jk' },
    timeout = vim.o.timeoutlen,
    check_modified = true,
    excluded_filetypes = {},
    escape_sequences = {
        ['i']    = '<BS><BS><ESC>',        -- insert mode
        ['ic']   = '<BS><BS><ESC>',
        ['ix']   = '<BS><BS><ESC>',
        ['R']    = '<BS><BS><RIGHT><ESC>', -- replace mode
        ['Rc']   = '<BS><BS><ESC>',
        ['Rx']   = '<BS><BS><ESC>',
        ['Rv']   = '<BS><BS><RIGHT><ESC>', -- virtual replace mode
        ['Rvc']  = '<BS><BS><ESC>',
        ['Rvx']  = '<BS><BS><ESC>',
        ['v']    = M.escape_and_undo,      -- visual mode
        ['vs']   = M.escape_and_undo,
        ['V']    = M.escape_and_undo,
        ['Vs']   = M.escape_and_undo,
        ['']   = M.escape_and_undo,
        ['s']  = M.escape_and_undo,
        ['no']   = M.escape_and_undo,      -- operator mode
        ['nov']  = M.escape_and_undo,
        ['noV']  = M.escape_and_undo,
        ['no'] = M.escape_and_undo,
        -- select mode
        ['s']  = '<BS><BS><ESC>:u! | call histdel("cmd", -1) | echo ""<CR>',
        ['S']  = '<BS><BS><ESC>:u! | call histdel("cmd", -1) | echo ""<CR>',
        [''] = '<BS><BS><ESC>:u! | call histdel("cmd", -1) | echo ""<CR>',

        ['t'] = '<BS><BS><C-\\><C-n>', -- terminal mode
        ['c'] = '<BS><BS><C-c>',       -- command line mode

        -- this is obviously a "hack" and will not work with inputs longer than 100 characters, but it should cover the majority of cases in Ex mode
        ['cv']  = ('<BS>'):rep(100) .. 'vi<CR>'
    },
}

---@type HoudiniConfiguration
M.config = defaults

local unmodified_buf_content = nil
---Save the current unmodified buffers content as a string for later comparisons
---If the current buffer is modified then the storage variable is set to `nil`
---Disable the whole comparison process by setting `check_modified = false`
local function save_buf_content_string()
    if M.config.check_modified then
        local modified = vim.api.nvim_get_option_value('modified', {})
        if not modified then
            local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
            unmodified_buf_content = table.concat(lines, '\n')
        else
            unmodified_buf_content = nil
        end
    end
end

---Setup the Houdini plugin with the given options
---You need to call this function at least once to be able to use the plugin
---Further calls will overwrite the previous configuration without needing a restart
---@param opts HoudiniConfiguration
function M.setup(opts)
    local config = defaults

    if opts then
        config = assert(vim.tbl_deep_extend('force', defaults, opts))

        for _, excluded_filetype in ipairs(config.excluded_filetypes)  do
            excluded_filetypes_set[excluded_filetype] = true
        end

        -- check that all mappings are valid
        local mappings = vim.tbl_filter(function(m)
            local valid = #m == 2
            if not valid then
                vim.api.nvim_err_writeln('[Houdini] The mapping "'..m..'" is not valid!')
            end
            return valid
        end, config.mappings)
        if #mappings == 0 then
            vim.api.nvim_err_writeln('[Houdini] There are no valid mappings! Use defaults')
            mappings = defaults.mappings
        end
        config.mappings = mappings

        -- check that timeout is actually a number
        if type(config.timeout) ~= 'number' then
            vim.api.nvim_err_writeln('[Houdini] The value for "timeout" has to be a number! Use default value')
            config.timeout = defaults.timeout
        end

        -- check for valid escape sequences
        local known_modes = vim.tbl_keys(defaults.escape_sequences)
        for mode, seq in pairs(config.escape_sequences) do
            if not vim.tbl_contains(known_modes, mode) then
                vim.api.nvim_echo({{ '[Houdini] Found escape sequence for not explicitly supported mode: "'..mode..'" (might not work)', 'WarningMsg' }}, true, {})
            end

            local type = type(seq)
            if type ~= 'string' and type ~= 'function' and seq ~= false then
                vim.api.nvim_err_writeln('[Houdini] Escape sequence for "'..mode..'" has to be either a string, a function or `false` (not '..type..')! Use default value (if present)')
                config.escape_sequences[mode] = defaults.escape_sequences[mode]
            end
        end
    end

    M.config = config

    combinations = {}
    for _, m in ipairs(M.config.mappings) do
        local firstChar  = m:sub(1, 1)
        local secondChar = m:sub(2, 2)

        if not combinations[firstChar] then
            combinations[firstChar] = {}
        end
        combinations[firstChar][secondChar] = true
    end

    vim.on_key(nil, ns)
    vim.on_key(function(_, char)
        -- if no char was actually typed we abort to avoid setting the last_char and last_mode variables to "invalid" values
        if not char or char == '' then
            return
        end

        if excluded_filetypes_set[vim.bo.filetype] then
            return
        end

        local mode = vim.api.nvim_get_mode().mode

        -- check the previous mode for escape sequences for cases where the mode was switched as part of the sequence
        if M.config.escape_sequences[mode] or M.config.escape_sequences[last_mode] then
            if timer:get_due_in() > 0 and combinations[last_char] and combinations[last_char][char] then
                -- if the timer's due time is equal to the configured timeout its a sign that the escape sequence
                -- was typed "automatically" (for example by `i_CTRL-A` or `i_CTRL-@`) and we should skip it (except its a macro)
                if timer and timer:get_due_in() == M.config.timeout and vim.fn.reg_executing() == '' then
                    return
                end

                local seq = M.config.escape_sequences[last_mode] or M.config.escape_sequences[mode]
                if type(seq) == 'function' then
                    seq = seq(last_char, char, last_cursor_pos, last_tick)
                end
                if not seq then
                    return
                end
                seq = vim.api.nvim_replace_termcodes(seq, true, true, true)
                vim.api.nvim_feedkeys(seq, 't', true)

                if M.config.check_modified then
                    -- check if the buffer content has changed, if not prevent modified state (only for "insert" modes)
                    local insert_modes = { 'i', 'ic', 'ix', 'R', 'Rc', 'Rx', 'Rv', 'Rvc', 'Rvx' }
                    if unmodified_buf_content and vim.tbl_contains(insert_modes, mode) then
                        local buf = vim.api.nvim_get_current_buf()
                        -- schedule needed for the escape sequence to be completed properly
                        vim.schedule(function()
                            if not vim.api.nvim_buf_is_valid(buf) then
                                return
                            end
                            local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
                            local content = table.concat(lines, '\n')
                            if content == unmodified_buf_content then
                                vim.api.nvim_buf_call(buf, function()
                                    local pos = vim.api.nvim_win_get_cursor(0)

                                    vim.cmd.undo { bang = true }

                                    -- save and restore cursor position in case the
                                    -- escape sequence is used for moving the cursor
                                    pcall(vim.api.nvim_win_set_cursor, 0, pos)
                                end)
                            end
                        end)
                    end
                end
            elseif combinations[char] then
                timer:stop()
                timer:start(M.config.timeout, 0, function() end)
            else
                -- add an extra `<Ignore>` key which is "moved between" the escape sequence chars after the macro recording finished
                if vim.fn.reg_recording() ~= '' and combinations[last_char] and combinations[last_char][char] then
                    vim.api.nvim_feedkeys(ignore_key, 't', true)
                end
            end

            last_char = char
            last_mode = mode
            last_tick = vim.b.changedtick
            last_cursor_pos = vim.api.nvim_win_get_cursor(0)
        end
    end, ns)

    vim.api.nvim_create_autocmd('InsertEnter', {
        group = vim.api.nvim_create_augroup('HoudiniCheckModified', {}),
        pattern = '*',
        callback = function()
            save_buf_content_string()
        end,
    })

    -- move the added `<Ignore>` key between the escape sequence chars
    -- during macro execution this will prevent triggering an escape
    vim.api.nvim_create_autocmd('RecordingLeave', {
        group = vim.api.nvim_create_augroup('HoudiniMacroAdaptions', {}),
        pattern = '*',
        callback = function()
            local reg = vim.fn.reg_recording()
            vim.schedule(function()
                local reg_content = vim.fn.getreg(reg)
                if reg_content and type(reg_content) == 'string' then
                    vim.fn.setreg(reg, reg_content:gsub('(.)' .. ignore_key, ignore_key .. '%1'))
                end
            end)
        end
    })
end

return M
