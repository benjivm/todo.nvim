local M = {}

M.defaults = {
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
}

M.options = {}

function M.setup(opts)
    M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
