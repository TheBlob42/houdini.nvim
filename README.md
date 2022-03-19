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
    escape_sequences = {
        i = '<LEFT><DEL><LEFT><DEL><ESC>',
        R = '<BS><BS><ESC>',
        t = '<BS><BS><C-\\><C-n>',
        c = '<C-c>',
    },
}
```

> The insert mode escape sequence looks a little funky, this is to avoid an issue with [lightspeed.nvim](https://github.com/ggandor/lightspeed.nvim) in some edge cases, see [issue 140](https://github.com/ggandor/lightspeed.nvim/issues/140). Once this is resolved we can change it to `<BS><BS><ESC>`

### `mappings`

A list of all two character mappings that you would like to use for "escaping"

### `timeout`

The time (in ms) within both keys need to be pressed to trigger the escape

### `escape_sequences`

The escape sequences which are used to escape a certain mode

You can provide another sequence as string or use a function for even more customization

```lua
require('houdini').setup {
    mappings = { 'jk', 'AA', 'II' },
    escape_sequences = {
        i = function(first, second)
            local seq = first..second
            local escape = '<LEFT><DEL><LEFT><DEL><ESC>A'

            if seq == 'AA' then
                -- jump to the end of the line in insert mode
                return escape..'A'
            end

            if seq == 'II' then
                -- jump to the beginning of the line in insert mode
                return escape..'I'
            end

            -- "regular" escape
            return escape
        end,
    },
}
```
