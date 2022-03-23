local M = {}

local ns = vim.api.nvim_create_namespace('houdini')
local timer = vim.loop.new_timer()

local combinations = {}
local trigger_char = nil

local defaults = {
    mappings = { 'jk' },
    timeout = vim.o.timeoutlen,
    escape_sequences = {
        -- prevent change issue with `lightspeed.nvim`
        -- https://github.com/ggandor/lightspeed.nvim/issues/140
        i = '<LEFT><DEL><LEFT><DEL><ESC>',
        R = '<BS><BS><ESC>',
        t = '<BS><BS><C-\\><C-n>',
        c = '<BS><BS><C-c>',
    },
}

M.config = defaults

function M.setup(opts)
    local config = defaults

    if opts then
        config = vim.tbl_deep_extend('force', defaults, opts)

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
        for mode, seq in pairs(config.escape_sequences) do
            if not vim.tbl_contains({ 'i', 'R', 't', 'c' }, mode) then
                vim.api.nvim_err_writeln('[Houdini] Found escape sequence for not supported mode (i,R,t,c): "'..mode..'"')
                config.escape_sequences[mode] = nil
            else
                local type = type(seq)
                if type ~= 'string' and type ~= 'function' and seq ~= false then
                    vim.api.nvim_err_writeln('[Houdini] Escape sequence for "'..mode..'" has to be either a string, a function or `false`! Use default value')
                    config.escape_sequences[mode] = defaults.escape_sequences[mode]
                end
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
    vim.on_key(function(char)
        local mode = vim.api.nvim_get_mode().mode
        if M.config.escape_sequences[mode] then
            if trigger_char and combinations[trigger_char][char] then
                local seq = M.config.escape_sequences[mode]
                if type(seq) == 'function' then
                    seq = seq(trigger_char, char)
                end
                seq = vim.api.nvim_replace_termcodes(seq, true, true, true)
                vim.api.nvim_feedkeys(seq, mode, true)

                trigger_char = nil
            elseif combinations[char] then
                trigger_char = char
                timer:stop()
                timer:start(M.config.timeout, 0, function()
                    trigger_char = nil
                end)
            else
                trigger_char = nil
            end
        end
    end, ns)
end

return M
