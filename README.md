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
        "FIXME",
        "FIX",
        "BUG",
        "HACK",
        "WARNING",
        "WARN",
        "NOTE",
        "INFO",
        "PERF",
        "OPTIMIZE",
        "XXX",
    },

    search_paths = { "." },

    keymap = "<leader>ft",

    highlights = {
        TODO = "TodoSignTODO",
        ["@todo"] = "TodoSignTODO",
        FIXME = "TodoSignFIXME",
        FIX = "TodoSignFIXME",
        BUG = "TodoSignBUG",
        HACK = "TodoSignHACK",
        WARNING = "TodoSignWARNING",
        WARN = "TodoSignWARNING",
        NOTE = "TodoSignNOTE",
        INFO = "TodoSignINFO",
        PERF = "TodoSignPERF",
        OPTIMIZE = "TodoSignPERF",
        XXX = "TodoSignXXX",
    },

    signs = {
        TODO = { text = "✓", texthl = "TodoSignTODO" },
        ["@todo"] = { text = "✓", texthl = "TodoSignTODO" },
        FIXME = { text = "!", texthl = "TodoSignFIXME" },
        FIX = { text = "!", texthl = "TodoSignFIXME" },
        BUG = { text = "✗", texthl = "TodoSignBUG" },
        HACK = { text = "⚡", texthl = "TodoSignHACK" },
        WARNING = { text = "⚠", texthl = "TodoSignWARNING" },
        WARN = { text = "⚠", texthl = "TodoSignWARNING" },
        NOTE = { text = "ℹ", texthl = "TodoSignNOTE" },
        INFO = { text = "ℹ", texthl = "TodoSignINFO" },
        PERF = { text = "⏱", texthl = "TodoSignPERF" },
        OPTIMIZE = { text = "⏱", texthl = "TodoSignPERF" },
        XXX = { text = "✗", texthl = "TodoSignXXX" },
    },
})
```

Use `.gitignore` or ripgrep's `.ignore` file to exclude directories from search.
