local M = {}

M.defaults = {
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
}

M.options = {}

function M.setup(opts)
    M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
