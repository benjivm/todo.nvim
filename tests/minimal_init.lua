-- Minimal init for running tests: nvim --headless --noplugin -u tests/minimal_init.lua
local root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")

vim.opt.runtimepath:prepend(root)
vim.opt.runtimepath:append(root .. "/.tests/mini.nvim")
vim.opt.swapfile = false
vim.opt.shadafile = "NONE"

vim.cmd("runtime plugin/todo-nvim.lua")

require("mini.test").setup({
    collect = {
        find_files = function()
            return vim.fn.globpath(root .. "/tests", "test_*.lua", true, true)
        end,
    },
})
