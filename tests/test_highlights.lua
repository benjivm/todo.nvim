local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/helpers.lua")
local config = require("todo-nvim.config")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({ hooks = { pre_case = H.reset } })

local function link(group)
    return vim.api.nvim_get_hl(0, { name = group }).link
end

T["links default groups to built-in groups"] = function()
    config.setup({ keywords = { IDEA = { icon = "?" }, CUSTOM = { icon = "c", hl = "MyGroup" } } })
    eq(link("TodoTODO"), "Todo")
    eq(link("TodoFIX"), "DiagnosticError")
    eq(link("TodoNOTE"), "DiagnosticHint")
    eq(link("TodoIDEA"), "Todo")
    eq(vim.tbl_isempty(vim.api.nvim_get_hl(0, { name = "MyGroup" })), true)
end

T["does not override user definitions"] = function()
    vim.api.nvim_set_hl(0, "TodoBUG", { fg = "#ff0000" })
    config.setup({})
    eq(vim.api.nvim_get_hl(0, { name = "TodoBUG" }).fg, 0xff0000)
end

T["are defined again after a colorscheme change"] = function()
    config.setup({})
    vim.cmd("highlight clear")
    vim.api.nvim_exec_autocmds("ColorScheme", {})
    eq(link("TodoHACK"), "DiagnosticWarn")
end

return T
