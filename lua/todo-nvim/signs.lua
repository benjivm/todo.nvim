local config = require("todo-nvim.config")

local M = {}

-- Namespace for signs
M.namespace = vim.api.nvim_create_namespace("todo-nvim")

-- Define the todo signs
function M.define_signs()
    for keyword, sign_config in pairs(config.options.signs) do
        local sign_name = "TodoSign_" .. keyword
        vim.fn.sign_define(sign_name, {
            text = sign_config.text,
            texthl = sign_config.texthl,
        })
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
        local line_text = vim.api.nvim_buf_get_lines(bufnr, todo.lnum - 1, todo.lnum, false)[1]
        if line_text then
            local start_col, end_col = line_text:find(todo.keyword, 1, true)
            if start_col then
                local hl_group = config.options.highlights[todo.keyword] or "TodoSignTODO"
                vim.api.nvim_buf_add_highlight(
                    bufnr,
                    M.namespace,
                    hl_group,
                    todo.lnum - 1,
                    start_col - 1,
                    end_col
                )
            end
        end
    end
end

return M
