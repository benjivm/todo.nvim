# Todo

A simple Todo navigator for Neovim.

- Signs and keyword highlights for `TODO`, `FIX`, `NOTE` and friends in open buffers
- Project-wide search with ripgrep, in a picker, the quickfix list or the location list
- Only keywords inside comments count (treesitter, including injected languages)

## Requirements

- Neovim 0.10+
- [ripgrep](https://github.com/BurntSushi/ripgrep) (`rg`)
- [snacks.nvim](https://github.com/folke/snacks.nvim) (optional, for the picker; falls back to `vim.ui.select`)

Run `:checkhealth todo-nvim` to check your setup.

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "benjivm/todo.nvim",
  dependencies = {
    "folke/snacks.nvim", -- optional
  },
  opts = {},
  keys = {
    { "<leader>ft", "<cmd>TodoPicker<cr>", desc = "Find todos" },
    { "]t", function() require("todo-nvim").jump_next() end, desc = "Next todo" },
    { "[t", function() require("todo-nvim").jump_prev() end, desc = "Previous todo" },
  },
}
```

The commands work without calling `setup()`. Signs need `setup()` (`opts = {}` does that with lazy.nvim).

## Commands

| Command | Description |
| --- | --- |
| `:TodoPicker [KW,...]` | Show todos in the picker. In snacks, `<A-k>` cycles the keyword filter. |
| `:TodoQuickfix [KW,...]` | Put todos in the quickfix list |
| `:TodoLocList [KW,...]` | Put todos in the location list |
| `:TodoSigns [on\|off\|toggle]` | Turn signs on or off |

The keyword list is optional and completes with `<Tab>`, e.g. `:TodoPicker TODO,FIX`.

## Configuration

Default configuration:

```lua
require("todo-nvim").setup({
    -- icon: sign text (1-2 cells), hl: highlight group, alt: other spellings
    keywords = {
        TODO = { icon = "✓", hl = "TodoTODO", alt = { "@todo" } },
        FIX  = { icon = "!", hl = "TodoFIX",  alt = { "FIXME" } },
        BUG  = { icon = "✗", hl = "TodoBUG" },
        HACK = { icon = "⚡", hl = "TodoHACK" },
        WARN = { icon = "⚠", hl = "TodoWARN", alt = { "WARNING" } },
        NOTE = { icon = "ℹ", hl = "TodoNOTE", alt = { "INFO" } },
        PERF = { icon = "⏱", hl = "TodoPERF", alt = { "OPTIMIZE" } },
        XXX  = { icon = "✗", hl = "TodoXXX" },
    },
    -- false = your keywords replace the defaults entirely
    merge_keywords = true,
    search_paths = { "." },
    -- "cwd" | "git" (git root of the current buffer)
    search_root = "cwd",
    signs = true,
    -- e.g. "<leader>ft" to map :TodoPicker
    keymap = false,
    -- delay before signs update after a change
    debounce_ms = 150,
    -- false = show every rg match, not only those in comments
    filter_comments = true,
})
```

Your keywords are merged into the defaults, so you only need to list what changes:

```lua
keywords = {
    IDEA = { icon = "?" },   -- add a keyword
    TODO = { icon = "T" },   -- change one field
    HACK = false,            -- remove a keyword
},
```

The highlight groups link to built-in groups (`Todo`, `DiagnosticError`, `DiagnosticWarn`, ...), so they follow your colorscheme. Override them with `vim.api.nvim_set_hl`. See `:help todo-nvim-highlights`.

Use `.gitignore` or ripgrep's `.ignore` file to exclude directories from search.

## Upgrading

The config changed in a breaking way: `keywords`, `highlights` and `signs` are now one `keywords` table, the highlight groups are renamed, the keymap is off by default, and Neovim 0.10 is required. See [UPGRADING.md](UPGRADING.md).

## Development

```sh
make test   # runs the tests with mini.test (cloned into .tests/)
make lint   # stylua --check
```
