# 🧙 Houdini

Escape insert mode, terminal mode and more with a simple two character mapping

## Motivation

Escaping from insert mode back to normal mode is the one action VIM users are (probably) doing most often. But `ESC` is hard to reach and `CTRL-\ CTRL-N` is too cumbersome. So Vimmers came up with a little [trick](https://vim.fandom.com/wiki/Avoid_the_escape_key#Mappings) to make their lives a little easier

```vimscript
imap jk <ESC>
```

But behold as this comes with a slight input delay

![typing with delay](./assets/with_delay.gif)

> Neovim is waiting for `timeoutlen` if you type the second key or if it should actually insert the character

`houdini` removes this delay

![typing without delay](./assets/without_delay.gif)

### But why stop in insert mode?

Compared to other [alternatives](#alternatives) `houdini` does also work for other modes and cases that you might want to escape easily using the same mapping and without any visible typing delay

- insert mode
- terminal mode
- command line mode
- (virtual) replace mode
- ex mode

## Installation

> Requires at least Neovim version `0.7.0`

Install with your favorite plugin manager and call the `setup` function

[lazy.nvim](https://github.com/folke/lazy.nvim)
```lua
{
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
        ['i']   = '<BS><BS><ESC>',
        ['ic']  = '<BS><BS><ESC>',
        ['ix']  = '<BS><BS><ESC>',
        ['R']   = '<BS><BS><RIGHT><ESC>',
        ['Rc']  = '<BS><BS><ESC>',
        ['Rx']  = '<BS><BS><ESC>',
        ['Rv']  = '<BS><BS><RIGHT><ESC>',
        ['Rvc'] = '<BS><BS><ESC>',
        ['Rvx'] = '<BS><BS><ESC>',
        ['r']   = '<ESC>',
        ['rm']  = '<ESC>',
        ['t']   = '<BS><BS><C-\\><C-n>',
        ['c']   = '<BS><BS><C-c>',
        ['cv']  = ('<BS>'):rep(100) .. 'vi<CR>'
    },
}
```

### `mappings`

A list of all two character mappings that you would like to use for "escaping"

### `timeout`

The time (ms) in which both keys need to be pressed successively to trigger the escape action

### `check_modified`

By default Neovim will always mark a buffer as `modified` after you've escaped insert mode via `houdini`. This is because inserting and deleting characters is considered a "change", even if you did not add/delete/modify any text

With this option enabled `houdini` will compare the changes made after leaving insert mode and suppress the `modified` status by Neovim, so that it works more like pressing `<ESC>`

This feature will not intervene in the following cases:

- the buffer was `modified` already before entering insert mode
- you changed some text while entering insert mode using for example `S`, `C` or `o`

### `escape_sequences`

The escape sequences which are used to escape a certain mode

> Check `:help mode()` for a detailed explanation of all the available mode options  
> See the [default configuration](#configuration) for all cases supported "out of the box" (and how its done)

You can provide your own sequence as a string or even use a function for more customization

```lua
require('houdini').setup {
    mappings = { 'jk', 'AA', 'II' },
    escape_sequences = {
        ['i'] = function(first, second)
            local seq = first..second

            if seq == 'AA' then
                -- jump to the end of the line in insert mode
                return '<BS><BS><End>'
            end

            if seq == 'II' then
                -- jump to the beginning of the line in insert mode
                return '<BS><BS><Home>'
            end

            -- you can also deactivate houdini for certain
            -- occasions by simply returning an empty string
            if vim.opt.filetype:get() == 'TelescopePrompt' then
                return ''
            end

            return '<BS><BS><ESC>'
        end,
        -- set the sequence of a specific mode to `false`
        -- in order to completely disable houdini for this mode
        ['c'] = false,
    },
}
```

## Alternatives

There are quite a few other plugins with a very similar scope:

- [better-escape.vim](https://github.com/jdhao/better-escape.vim)
- [better-escape.nvim](https://github.com/max397574/better-escape.nvim)
- [vim-easyescape](https://github.com/zhou13/vim-easyescape)

They all use the `InserCharPre` autocommand event to implement their logic which limits their functionality to insert mode only. For `houdini` we add a custom function via `vim.on_key` that handles everything. This brings several advantages:

- works in (almost) all [modes](#but-why-stop-in-insert-mode%3F)
- [escape sequence functions](#escape-sequences) allow a lot of customization
- works "flawless" in macros

## Troubleshooting

### General

Most of the work performed by `houdini` happens inside a custom function registered via `vim.on_key`. Whenever an error occurs in there this custom function will be removed from being triggered anymore. So in case `houdini` is suddenly not working anymore it is mostly because of an error. In these cases check `:messages` for error logs and open an issue to start the investigation

### Macros with `:normal`

In case you encounter issues while executing macros via `:normal` you might need to update your Neovim version to at least `v0.10.0-dev-1902+g184f84234` (20.12.2023) see [here](https://github.com/TheBlob42/houdini.nvim/issues/7) for more information

### Lightspeed

There is a known issue with [lightspeed.nvim](https://github.com/ggandor/lightspeed.nvim) which blocks the first `<BS>` after a jump and changing text. This conflicts with the default escape sequence for insert mode. Fortunately there is a simple workaround to mitigate this problem, see [here](https://github.com/ggandor/lightspeed.nvim/issues/140) for more information
