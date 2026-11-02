local config = require("todo-nvim.config")

local M = {}

--- Path relative to the search root, or unchanged if outside it.
function M.relative(path, root)
    if root then
        local prefix = root:gsub("[\\/]$", "") .. "/"
        if path:sub(1, #prefix) == prefix then
            return path:sub(#prefix + 1)
        end
    end
    return path
end

---@param todos todo.Item[]
---@param root? string
---@return table[]
local function to_items(todos, root)
    local lookup = config.get_lookup()
    local items = {}
    for _, todo in ipairs(todos) do
        local kw = lookup[todo.word] or { icon = " ", hl = "Todo" }
        local rel = M.relative(todo.filepath, root)
        table.insert(items, {
            -- What the picker matches against
            text = ("%s %s %s"):format(todo.keyword, rel, todo.text),
            file = todo.filepath,
            pos = { todo.lnum, todo.col - 1 },
            rel = rel,
            todo = todo,
            icon = kw.icon,
            hl = kw.hl,
        })
    end
    return items
end

local function jump(todo)
    vim.cmd.edit(vim.fn.fnameescape(todo.filepath))
    pcall(vim.api.nvim_win_set_cursor, 0, { todo.lnum, todo.col - 1 })
end

--- Fallback when snacks.nvim is not installed.
local function select(items)
    vim.ui.select(items, {
        prompt = "Todos",
        format_item = function(item)
            return ("%s %s:%d: %s"):format(item.icon, item.rel, item.todo.lnum, item.todo.text)
        end,
    }, function(item)
        if item then
            jump(item.todo)
        end
    end)
end

--- Keyword names present in the items, in config order.
local function present_keywords(items)
    local present = {}
    for _, item in ipairs(items) do
        present[item.todo.keyword] = true
    end
    return vim.tbl_filter(function(name)
        return present[name]
    end, config.keyword_names())
end

---@param todos todo.Item[]
---@param opts? { root?: string }
function M.show(todos, opts)
    opts = opts or {}
    local items = to_items(todos, opts.root)

    local ok, snacks = pcall(require, "snacks")
    if not ok or not (snacks.picker and snacks.picker.pick) then
        select(items)
        return
    end

    -- false = all keywords
    local filters = { false }
    vim.list_extend(filters, present_keywords(items))
    local current = 1

    local function title()
        local name = filters[current]
        return name and ("Todos (%s)"):format(name) or "Todos"
    end

    snacks.picker.pick({
        source = "todo",
        title = title(),
        finder = function()
            local name = filters[current]
            if not name then
                return items
            end
            return vim.tbl_filter(function(item)
                return item.todo.keyword == name
            end, items)
        end,
        format = function(item)
            return {
                { item.icon .. " ", item.hl },
                { item.todo.keyword, item.hl },
                { " " },
                { item.rel, "Directory" },
                { ":", "Comment" },
                { tostring(item.todo.lnum), "LineNr" },
                { ": ", "Comment" },
                { item.todo.text, "Normal" },
            }
        end,
        preview = "file",
        actions = {
            todo_cycle_keyword = function(picker)
                current = current % #filters + 1
                picker.title = title()
                picker:find()
            end,
        },
        win = {
            input = {
                keys = {
                    ["<a-k>"] = { "todo_cycle_keyword", mode = { "n", "i" }, desc = "Cycle keyword filter" },
                },
            },
            list = {
                keys = {
                    ["<a-k>"] = { "todo_cycle_keyword", desc = "Cycle keyword filter" },
                },
            },
        },
    })
end

--- Quickfix list entries for todos.
---@param todos todo.Item[]
function M.to_qf_items(todos)
    return vim.tbl_map(function(todo)
        return {
            filename = todo.filepath,
            lnum = todo.lnum,
            col = todo.col,
            text = todo.text,
            user_data = { keyword = todo.keyword },
        }
    end, todos)
end

--- Fill and open the quickfix list, or the location list when `loclist`.
---@param todos todo.Item[]
---@param loclist? boolean
function M.set_list(todos, loclist)
    local what = { title = "Todos", items = M.to_qf_items(todos) }
    if loclist then
        vim.fn.setloclist(0, {}, " ", what)
        vim.cmd("lopen")
    else
        vim.fn.setqflist({}, " ", what)
        vim.cmd("copen")
    end
end

return M
