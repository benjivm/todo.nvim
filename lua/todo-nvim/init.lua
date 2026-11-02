local config = require("todo-nvim.config")
local search = require("todo-nvim.search")
local picker = require("todo-nvim.picker")
local signs = require("todo-nvim.signs")

local M = {}

-- Setup function
function M.setup(opts)
    config.setup(opts)

    -- Set up keymap if configured
    if config.get().keymap then
        vim.keymap.set("n", config.get().keymap, "<cmd>TodoPicker<cr>", { desc = "Find Callouts" })
    end

    -- Define signs
    signs.define_signs()

    -- Set up autocommand to refresh signs in current buffer only
    local group = vim.api.nvim_create_augroup("TodoNvim", { clear = true })

    vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost", "TextChanged", "InsertLeave" }, {
        group = group,
        callback = function(ev)
            -- Only refresh signs for the current buffer
            -- Use vim.schedule to avoid fast event context issues
            vim.schedule(function()
                signs.refresh_buffer(ev.buf)
            end)
        end,
    })
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
