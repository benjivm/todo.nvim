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

local function with_todos(opts, fn)
    M.collect(opts, function(todos, root)
        if #todos == 0 then
            vim.notify("No todos found", vim.log.levels.INFO)
            return
        end
        fn(todos, root)
    end)
end

--- Show todos in the picker (snacks.nvim, or vim.ui.select without it).
---@param opts? { keywords?: string[] }
function M.show(opts)
    with_todos(opts, function(todos, root)
        picker.show(todos, { root = root })
    end)
end

--- Put todos in the quickfix list and open it.
---@param opts? { keywords?: string[] }
function M.quickfix(opts)
    with_todos(opts, function(todos)
        picker.set_list(todos, false)
    end)
end

--- Put todos in the current window's location list and open it.
---@param opts? { keywords?: string[] }
function M.loclist(opts)
    with_todos(opts, function(todos)
        picker.set_list(todos, true)
    end)
end

--- Parse command arguments like `TODO,FIX` or `TODO FIXME` into keyword
--- names. Alt names map to their keyword.
---@param args string[]
---@return string[]|nil names, string|nil err
function M.parse_keywords(args)
    local lookup = config.get_lookup()
    local names, seen = {}, {}
    for _, arg in ipairs(args) do
        for word in arg:gmatch("[^,%s]+") do
            local kw = lookup[word]
            if not kw then
                return nil, ("Unknown keyword %q"):format(word)
            end
            if not seen[kw.name] then
                seen[kw.name] = true
                table.insert(names, kw.name)
            end
        end
    end
    return #names > 0 and names or nil
end

--- Command-line completion for a comma-separated keyword list.
---@param arglead string
---@return string[]
function M.complete_keywords(arglead)
    local prefix, last = arglead:match("^(.*,)([^,]*)$")
    if not prefix then
        prefix, last = "", arglead
    end
    local used = {}
    for word in prefix:gmatch("[^,]+") do
        used[word] = true
    end
    local result = {}
    for _, name in ipairs(config.keyword_names()) do
        if not used[name] and name:lower():find(last:lower(), 1, true) == 1 then
            table.insert(result, prefix .. name)
        end
    end
    return result
end

return M
