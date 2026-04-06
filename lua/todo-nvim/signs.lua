local config = require("todo-nvim.config")

local M = {}

-- Namespace for signs
M.namespace = vim.api.nvim_create_namespace("todo-nvim")

-- Define the todo sign
function M.define_signs()
    vim.fn.sign_define("TodoSign", {
        text = "✓",
        texthl = "TodoSignTODO",
    })
end

-- Search for TODOs in a specific buffer
local function search_buffer_todos(bufnr)
    local todos = {}
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local filepath = vim.api.nvim_buf_get_name(bufnr)

    if filepath == "" then
        return todos
    end

    for lnum, line in ipairs(lines) do
        for _, keyword in ipairs(config.options.keywords) do
            if line:find(keyword, 1, true) then
                table.insert(todos, {
                    filepath = filepath,
                    lnum = lnum,
                    text = vim.trim(line),
                    keyword = keyword,
                })
                break -- Only add once per line even if multiple keywords match
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

    -- Search and place signs
    local todos = search_buffer_todos(bufnr)

    for _, todo in ipairs(todos) do
        vim.fn.sign_place(0, "todo-nvim", "TodoSign", bufnr, {
            lnum = todo.lnum,
            priority = 10,
        })
    end
end

return M
