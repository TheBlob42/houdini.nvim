```text
$$\                                 $$\ $$\           $$\
$$ |                                $$ |\__|          \__|
$$$$$$$\   $$$$$$\  $$\   $$\  $$$$$$$ |$$\ $$$$$$$\  $$\
$$  __$$\ $$  __$$\ $$ |  $$ |$$  __$$ |$$ |$$  __$$\ $$ |
$$ |  $$ |$$ /  $$ |$$ |  $$ |$$ /  $$ |$$ |$$ |  $$ |$$ |
$$ |  $$ |$$ |  $$ |$$ |  $$ |$$ |  $$ |$$ |$$ |  $$ |$$ |
$$ |  $$ |\$$$$$$  |\$$$$$$  |\$$$$$$$ |$$ |$$ |  $$ |$$ |
\__|  \__| \______/  \______/  \_______|\__|\__|  \__|\__|
```

Use a simple two character mapping to escape insert, terminal & command mode

If you are using a custom key mapping like `jk` to leave insert, terminal or command mode you probably have noticed that there is a slight "delay" after typing the first character. This is Neovim waiting for `vim.o.timeoutlen` to see if you type the second character of your mapping or if it should insert the character instead

With delay (using a mapping like `inoremap jk <esc>`)

![with delay](./assets/with_delay.gif)

Without delay (using `houdini`)

![without delay](./assets/without_delay.gif)

## Motivation

There are quite a few other plugins that also tackle this issue:

- [better-escape.vim](https://github.com/jdhao/better-escape.vim)
- [better-escape.nvim](https://github.com/max397574/better-escape.nvim)
- [vim-easyescape](https://github.com/zhou13/vim-easyescape)

All of these are using the `InsertCharPre` autocommand event to implement their functionality, which only works for insert mode. For `houdini` we use the `vim.on_key` function of Neovim instead to also handle terminal and command mode properly. Furthermore the usage of escape functions allows for even more advance configurations, see [escape_sequences](#escape_sequences) for an example

> If all you care about is insert mode escaping then any of the mentioned plugins will do the job just fine

## Installation

Install with your favorite plugin manager and call the `setup` function

[packer.nvim](https://github.com/wbthomason/packer.nvim)
```lua
use {
    'TheBlob42/houdini.nvim',
    config = function()
        require('houdini').setup()
    end
}
```

## Configuration

Call the `setup` function with your own configuration table to overwrite the defaults

```lua
-- default settings
require('houdini').setup {
    mappings = { 'jk' },
    timeout = vim.o.timeoutlen,
    check_modified = true,
    escape_sequences = {
        i = '<BS><BS><ESC>',
        R = '<BS><BS><ESC>',
        t = '<BS><BS><C-\\><C-n>',
        c = '<BS><BS><C-c>',
    },
}
```

### `mappings`

A list of all two character mappings that you would like to use for "escaping"

### `timeout`

The time (in ms) within both keys need to be pressed to trigger the escape

### `check_modified`

Neovim will always mark a buffer as `modified` after you've escaped insert mode via `houdini`. This is because inserting and deleting characters is considered a "change", even if you did not change any text. With this option enabled `houdini` will compare the changes made after leaving insert mode and suppress the `modified` status by Neovim, so that it works more like pressing `<ESC>`

This feature will not intervene in the following cases:

- the buffer was `modified` already before entering insert mode
- you changed some text while entering insert mode using for example `S`, `C` or `o`

### `escape_sequences`

The escape sequences which are used to escape a certain mode

You can provide another sequence as string or use a function for even more customization

```lua
require('houdini').setup {
    mappings = { 'jk', 'AA', 'II' },
    escape_sequences = {
        i = function(first, second)
            local seq = first..second

            if seq == 'AA' then
                -- jump to the end of the line in insert mode
                return '<BS><BS><End>'
            end
            if seq == 'II' then
                -- jump to the beginning of the line in insert mode
                return '<BS><BS><Home>'
            end
            return '<BS><BS><ESC>'
        end,
    },
}
```

Furthermore you can set a sequence to `false` to completely disable `houdini` for the specific mode

## Troubleshooting

### General

Whenever there is an error in a function used by `vim.on_key` Neovim will remove this function afterwards. So if `houdini` suddenly stops working it is most probably due to this. In this situation please check the `:messages` for error logs and open an issue, so we can further investigate it

### Lightspeed

There is a known issue with [lightspeed.nvim](https://github.com/ggandor/lightspeed.nvim) which blocks the first `<BS>` after a jump and changing text (see [here](https://github.com/ggandor/lightspeed.nvim/issues/140) fore more information). This might conflict with the default escape sequence for insert mode. Fortunately there is a simple workaround to mitigate this problem:

```lua
-- needs at least nvim version 0.7
vim.api.nvim_create_autocmd('User', {
    desc = 'fix for https://github.com/ggandor/lightspeed.nvim/issues/140',
    pattern = 'LightspeedSxLeave',
    callback = function()
        local ignore = vim.tbl_contains({ 'terminal', 'prompt' }, vim.opt.buftype:get())
        if vim.opt.modifiable:get() and not ignore then
            vim.cmd('normal! a')
        end
    end,
})
```
