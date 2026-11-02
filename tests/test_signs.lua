local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/helpers.lua")
local config = require("todo-nvim.config")
local signs = require("todo-nvim.signs")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            H.reset()
            config.setup({})
            signs.set_enabled(true)
        end,
        post_case = function()
            vim.cmd("silent! %bwipeout!")
        end,
    },
})

local function marks(bufnr)
    return vim.tbl_map(function(m)
        local d = m[4]
        return { m[2], m[3], d.end_col, vim.trim(d.sign_text), d.hl_group, d.sign_hl_group }
    end, vim.api.nvim_buf_get_extmarks(bufnr, signs.ns, 0, -1, { details = true }))
end

local fixture = {
    "local TODO_LIST = {} -- TODO: x",
    "local DEBUG = 1",
    'local s = "FIX this" -- FIXME later',
    "-- NOTE: a BUG too",
}

T["places one extmark per line for the leftmost comment keyword"] = function()
    local bufnr = H.make_buf(fixture, "lua")
    signs.refresh(bufnr)
    eq(marks(bufnr), {
        { 0, 24, 28, "✓", "TodoTODO", "TodoTODO" },
        { 2, 24, 29, "!", "TodoFIX", "TodoFIX" },
        { 3, 3, 7, "ℹ", "TodoNOTE", "TodoNOTE" },
    })
end

T["uses custom keywords"] = function()
    config.setup({ keywords = { IDEA = { icon = "?" } } })
    local bufnr = H.make_buf({ "-- IDEA: x" }, "lua")
    signs.refresh(bufnr)
    eq(marks(bufnr), { { 0, 3, 7, "?", "TodoIDEA", "TodoIDEA" } })
end

T["skips special and unnamed buffers"] = function()
    local special = H.make_buf({ "-- TODO" }, "lua")
    vim.bo[special].buftype = "nofile"
    local unnamed = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_lines(unnamed, 0, -1, false, { "-- TODO" })
    vim.bo[unnamed].filetype = "lua"
    signs.refresh(special)
    signs.refresh(unnamed)
    eq({ marks(special), marks(unnamed) }, { {}, {} })
end

T["can be turned off and on"] = function()
    local bufnr = H.make_buf(fixture, "lua")
    signs.refresh(bufnr)
    signs.set_enabled(false)
    eq(marks(bufnr), {})
    signs.refresh(bufnr)
    eq(marks(bufnr), {})
    signs.toggle()
    eq(#marks(bufnr), 3)
end

T["respects signs = false"] = function()
    config.setup({ signs = false })
    package.loaded["todo-nvim.signs"] = nil
    local fresh = require("todo-nvim.signs")
    local bufnr = H.make_buf(fixture, "lua")
    fresh.refresh(bufnr)
    eq(#vim.api.nvim_buf_get_extmarks(bufnr, fresh.ns, 0, -1, {}), 0)
    package.loaded["todo-nvim.signs"] = signs
end

T["updates after text changes (debounced)"] = function()
    config.setup({ debounce_ms = 10 })
    signs.setup()
    local bufnr = H.make_buf({ "-- nothing" }, "lua")
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, { "-- HACK: now" })
    vim.api.nvim_exec_autocmds("TextChanged", { buffer = bufnr })
    eq(
        vim.wait(1000, function()
            return #marks(bufnr) == 1
        end),
        true
    )
end

T["jumps between todos"] = function()
    local bufnr = H.make_buf(fixture, "lua")
    vim.api.nvim_set_current_buf(bufnr)
    signs.refresh(bufnr)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    local todo = require("todo-nvim")
    todo.jump_next()
    eq(vim.api.nvim_win_get_cursor(0), { 1, 24 })
    todo.jump_next()
    eq(vim.api.nvim_win_get_cursor(0), { 3, 24 })
    todo.jump_next()
    todo.jump_next()
    eq(vim.api.nvim_win_get_cursor(0), { 1, 24 }) -- wrapscan
    todo.jump_prev()
    eq(vim.api.nvim_win_get_cursor(0), { 4, 3 })
end

T["only scans the visible part of large files"] = function()
    local lines = {}
    for i = 1, signs.large_file_lines + 1 do
        lines[i] = "-- TODO " .. i
    end
    local bufnr = H.make_buf(lines, "lua")
    vim.api.nvim_set_current_buf(bufnr)
    vim.api.nvim_win_set_cursor(0, { 1, 0 })
    signs.refresh(bufnr)
    local count = #marks(bufnr)
    eq(count > 0 and count < 100, true)
    eq(count, vim.fn.line("w$") - vim.fn.line("w0") + 1)
end

return T
