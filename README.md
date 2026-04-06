# Todo

A simple Todo navigator for Neovim.

- Neovim 0.9.0+
- [ripgrep](https://github.com/BurntSushi/ripgrep) (`rg`)
- [snacks.nvim](https://github.com/folke/snacks.nvim) (picker)

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "benjivm/todo.nvim",
  dependencies = {
    "folke/snacks.nvim",
  },
  config = function()
    require('todo-nvim').setup()
  end,
}
```

## Configuration

Default configuration:

```lua
require('todo-nvim').setup({
    keywords = {
        "TODO",
        "@todo",
    },

    search_paths = { "." },

    keymap = "<leader>ft",

    highlights = {
        TODO = "TodoSignTODO",
        ["@todo"] = "TodoSignTODO",
    },
})
```

Use `.gitignore` or ripgrep's `.ignore` file to exclude directories from search.
