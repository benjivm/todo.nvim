local M = {}

-- Built-in groups the default keyword highlights link to
M.links = {
    TODO = "Todo",
    FIX = "DiagnosticError",
    BUG = "DiagnosticError",
    HACK = "DiagnosticWarn",
    WARN = "DiagnosticWarn",
    NOTE = "DiagnosticHint",
    PERF = "DiagnosticInfo",
    XXX = "DiagnosticError",
}

local autocmd_created = false

--- Define the keyword highlight groups. Uses `default = true`, so user and
--- colorscheme definitions win.
function M.apply()
    local config = require("todo-nvim.config")
    for name, kw in pairs(config.options and config.options.keywords or {}) do
        -- Only define groups we own; a user-chosen hl like "Error" is left alone
        if kw.hl == config.default_hl(name) then
            vim.api.nvim_set_hl(0, kw.hl, { link = M.links[name] or "Todo", default = true })
        end
    end

    if not autocmd_created then
        autocmd_created = true
        vim.api.nvim_create_autocmd("ColorScheme", {
            group = vim.api.nvim_create_augroup("TodoNvimHighlights", { clear = true }),
            callback = M.apply,
        })
    end
end

return M
