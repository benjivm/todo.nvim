local config = require("todo-nvim.config")
local filter = require("todo-nvim.filter")
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

--- Search for todos, keeping only those in comments when `filter_comments`
--- is set, and one per line.
---@param opts? { keywords?: string[] } keyword names to limit the search to
---@param callback fun(todos: todo.Item[], root: string)
function M.collect(opts, callback)
    opts = opts or {}
    search.search_todos({ keywords = opts.keywords }, function(items, root)
        filter.filter(items, { comments = config.get().filter_comments }, function(todos)
            callback(todos, root)
        end)
    end)
end

--- Show todos in the picker.
---@param opts? { keywords?: string[] }
function M.show(opts)
    M.collect(opts, function(todos)
        if #todos == 0 then
            vim.notify("No todos found", vim.log.levels.INFO)
            return
        end
        picker.show(todos)
    end)
end

return M
