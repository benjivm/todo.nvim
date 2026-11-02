# Upgrading

## To the keywords table config

This release changes the config in a breaking way. There is no compatibility layer, so old configs need updating.

### Requirements

- Neovim **0.10** or later is now required (was 0.9).
- snacks.nvim is now optional. Without it, `:TodoPicker` uses `vim.ui.select`.

Run `:checkhealth todo-nvim` after upgrading. It reports unknown options and invalid keywords.

### `keywords`, `highlights` and `signs` are one table

Previously a keyword was spread over three options: the `keywords` list, a `highlights` entry and a `signs` entry. Now each keyword is one entry in `keywords`, keyed by name:

| Field | Required | Description |
| --- | --- | --- |
| `icon` | yes | Sign text, 1–2 cells wide (was `signs[KW].text`) |
| `hl` | no | Highlight group for the sign and the keyword (was `highlights[KW]` / `signs[KW].texthl`). Defaults to `Todo<NAME>`. |
| `alt` | no | Other spellings that count as this keyword |

Remove `highlights` and `signs` from your config. Unknown options are reported as a warning.

Before:

```lua
require("todo-nvim").setup({
    keywords = { "TODO", "FIXME", "FIX", "IDEA" },
    highlights = {
        TODO = "TodoSignTODO",
        FIXME = "TodoSignFIXME",
        FIX = "TodoSignFIXME",
        IDEA = "MyIdeaHl",
    },
    signs = {
        TODO = { text = "✓", texthl = "TodoSignTODO" },
        FIXME = { text = "!", texthl = "TodoSignFIXME" },
        FIX = { text = "!", texthl = "TodoSignFIXME" },
        IDEA = { text = "?", texthl = "MyIdeaHl" },
    },
})
```

After:

```lua
require("todo-nvim").setup({
    keywords = {
        IDEA = { icon = "?", hl = "MyIdeaHl" },
    },
})
```

### Your keywords are merged into the defaults

Previously, setting `keywords` merged your list with the default list position by position, which gave odd results. Now:

- Keywords you list are added to the defaults, or change only the fields you set: `TODO = { icon = "T" }` keeps the default `hl` and `alt`.
- `NAME = false` removes a default keyword.
- `merge_keywords = false` uses only your keywords.

If your old config listed a subset of keywords to limit what was matched, use `merge_keywords = false`:

```lua
require("todo-nvim").setup({
    merge_keywords = false,
    keywords = {
        TODO = { icon = "✓" },
        FIX = { icon = "!", alt = { "FIXME" } },
    },
})
```

Other lists, like `search_paths`, now replace the default list instead of merging with it.

### Alternative spellings are part of their keyword

These used to be separate keywords. They are now `alt` names, so they share the icon and highlight of their keyword and appear under it in the picker:

| Old keyword | Now an `alt` of |
| --- | --- |
| `@todo` | `TODO` |
| `FIXME` | `FIX` |
| `WARNING` | `WARN` |
| `INFO` | `NOTE` |
| `OPTIMIZE` | `PERF` |

`INFO` and `OPTIMIZE` used to have their own `TodoSignINFO` colour and now use `NOTE`'s and `PERF`'s. To keep one separate, define it as its own keyword and remove it from the default's `alt`:

```lua
keywords = {
    NOTE = { alt = {} },
    INFO = { icon = "ℹ" },
},
```

### Highlight groups are renamed and link to built-in groups

The groups no longer use fixed hex colours. They are defined with `default = true`, so your colorscheme or config can override them:

| Old group | New group | Links to |
| --- | --- | --- |
| `TodoSignTODO` | `TodoTODO` | `Todo` |
| `TodoSignFIXME` | `TodoFIX` | `DiagnosticError` |
| `TodoSignBUG` | `TodoBUG` | `DiagnosticError` |
| `TodoSignHACK` | `TodoHACK` | `DiagnosticWarn` |
| `TodoSignWARNING` | `TodoWARN` | `DiagnosticWarn` |
| `TodoSignNOTE` | `TodoNOTE` | `DiagnosticHint` |
| `TodoSignINFO` | `TodoNOTE` | `DiagnosticHint` |
| `TodoSignPERF` | `TodoPERF` | `DiagnosticInfo` |
| `TodoSignXXX` | `TodoXXX` | `DiagnosticError` |

If you set colours for the old groups, rename them. To get the old colours back:

```lua
vim.api.nvim_set_hl(0, "TodoTODO", { fg = "#7aa2f7", bold = true })
vim.api.nvim_set_hl(0, "TodoFIX", { fg = "#f7768e", bold = true })
vim.api.nvim_set_hl(0, "TodoBUG", { fg = "#db4b4b", bold = true })
vim.api.nvim_set_hl(0, "TodoHACK", { fg = "#ff9e64", bold = true })
vim.api.nvim_set_hl(0, "TodoWARN", { fg = "#e0af68", bold = true })
vim.api.nvim_set_hl(0, "TodoNOTE", { fg = "#1abc9c", bold = true })
vim.api.nvim_set_hl(0, "TodoPERF", { fg = "#bb9af7", bold = true })
vim.api.nvim_set_hl(0, "TodoXXX", { fg = "#f7768e", bold = true })
```

Set these in a `ColorScheme` autocmd too if you switch colorschemes.

### The keymap is off by default

`keymap` used to default to `<leader>ft`. It now defaults to `false`. Either set it:

```lua
require("todo-nvim").setup({ keymap = "<leader>ft" })
```

or map it with lazy.nvim's `keys`:

```lua
keys = {
    { "<leader>ft", "<cmd>TodoPicker<cr>", desc = "Find todos" },
},
```

### Signs use extmarks

Signs are now extmarks in the `todo-nvim` namespace. The `TodoSign_<KEYWORD>` sign definitions and the `todo-nvim` sign group no longer exist, so code that used `sign_getplaced()` or `sign_getdefined()` for them needs to use `nvim_buf_get_extmarks()` instead.

### Matching is stricter

- Keywords match on word boundaries everywhere. Signs used to match `BUG` inside `DEBUG` and `FIX` inside `PREFIX`; they no longer do.
- Signs and the picker use the same comment check. A word like `TODO_LIST` in code, or `BUG` in a string, no longer gets a sign.
- The picker shows one entry per line (the first keyword in a comment), where it used to show one per match.

### New features

None of these need config changes:

- `:TodoPicker`, `:TodoQuickfix` and `:TodoLocList` take an optional keyword list, e.g. `:TodoPicker TODO,FIX`.
- `<A-k>` in the snacks picker cycles the keyword filter.
- `:TodoSigns [on|off|toggle]`.
- `require("todo-nvim").jump_next()` / `jump_prev()` for `]t` / `[t` mappings.
- Options `search_root`, `signs`, `debounce_ms` and `filter_comments`. See `:help todo-nvim-options`.
