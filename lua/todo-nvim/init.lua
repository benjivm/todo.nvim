local config = require("todo-nvim.config")
local search = require("todo-nvim.search")
local picker = require("todo-nvim.picker")
local signs = require("todo-nvim.signs")

local M = {}

function M.setup(opts)
    config.setup(opts)

    local keymap = config.get().keymap
    if keymap then
        vim.keymap.set("n", keymap, "<cmd>TodoPicker<cr>", { desc = "Find todos" })
    end

    signs.setup()
end

--- Jump to the next todo in the current buffer.
function M.jump_next()
    signs.jump(1)
end

--- Jump to the previous todo in the current buffer.
function M.jump_prev()
    signs.jump(-1)
end

-- Check if a position is inside a comment using treesitter
local function is_in_comment(filepath, row, col)
    -- Get or load the buffer for this file
    local bufnr = vim.fn.bufnr(filepath)

    -- If buffer doesn't exist, try to load it
    if bufnr == -1 then
        bufnr = vim.fn.bufadd(filepath)
        vim.fn.bufload(bufnr)
    end

    return require("todo-nvim.match").in_comment(bufnr, row - 1, col - 1)
end

-- Filter todos to only include those in comments
local function filter_todos_in_comments(todos)
    local filtered = {}
    for _, todo in ipairs(todos) do
        if is_in_comment(todo.filepath, todo.lnum, todo.col) then
            table.insert(filtered, todo)
        end
    end
    return filtered
end

-- Main command to show callouts
function M.show()
    search.search_todos(function(todos)
        vim.schedule(function()
            -- Filter to only show todos that are in comments
            local filtered_todos = filter_todos_in_comments(todos)

            if #filtered_todos == 0 then
                vim.notify("No callouts found", vim.log.levels.INFO)
                return
            end

            picker.show(filtered_todos)
        end)
    end)
end

return M
