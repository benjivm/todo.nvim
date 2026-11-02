local config = require("todo-nvim.config")
local match = require("todo-nvim.match")

local M = {}

-- Namespace for signs
M.namespace = vim.api.nvim_create_namespace("todo-nvim")

-- Define the todo signs
function M.define_signs()
    for word, kw in pairs(config.get_lookup()) do
        vim.fn.sign_define("TodoSign_" .. word, { text = kw.icon, texthl = kw.hl })
    end
end

-- Search for TODOs in a specific buffer
local function search_buffer_todos(bufnr)
    local todos = {}
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local filepath = vim.api.nvim_buf_get_name(bufnr)

    if filepath == "" then
        return todos
    end

    local in_comment = match.buf_checker(bufnr)
    for lnum, line in ipairs(lines) do
        -- Leftmost keyword that is in a comment
        for _, m in ipairs(match.find(line)) do
            if in_comment(lnum - 1, m.start_col) then
                table.insert(todos, { lnum = lnum, keyword = m.word, match = m })
                break
            end
        end
    end

    return todos
end

-- Refresh signs for a specific buffer
function M.refresh_buffer(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    -- Skip if buffer is not loaded or valid
    if not vim.api.nvim_buf_is_loaded(bufnr) then
        return
    end

    -- Clear existing signs for this buffer
    vim.fn.sign_unplace("todo-nvim", { buffer = bufnr })

    -- Clear existing highlights
    vim.api.nvim_buf_clear_namespace(bufnr, M.namespace, 0, -1)

    -- Search and place signs + highlights
    local todos = search_buffer_todos(bufnr)

    for _, todo in ipairs(todos) do
        local sign_name = "TodoSign_" .. todo.keyword

        -- Place sign
        vim.fn.sign_place(0, "todo-nvim", sign_name, bufnr, {
            lnum = todo.lnum,
            priority = 10,
        })

        -- Add syntax highlighting for the keyword in the buffer
        local hl_group = config.get_lookup()[todo.keyword].hl
        vim.api.nvim_buf_add_highlight(
            bufnr,
            M.namespace,
            hl_group,
            todo.lnum - 1,
            todo.match.start_col,
            todo.match.end_col
        )
    end
end

return M
