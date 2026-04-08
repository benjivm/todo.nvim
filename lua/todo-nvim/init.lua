local config = require("todo-nvim.config")
local search = require("todo-nvim.search")
local picker = require("todo-nvim.picker")
local signs = require("todo-nvim.signs")

local M = {}

-- Setup function
function M.setup(opts)
    config.setup(opts)

    -- Set up highlight groups if they don't exist
    local highlights = {
        TodoSignTODO = { fg = "#7aa2f7", bold = true }, -- Blue
        TodoSignFIXME = { fg = "#f7768e", bold = true }, -- Red
        TodoSignBUG = { fg = "#db4b4b", bold = true }, -- Dark Red
        TodoSignHACK = { fg = "#ff9e64", bold = true }, -- Orange
        TodoSignWARNING = { fg = "#e0af68", bold = true }, -- Yellow
        TodoSignNOTE = { fg = "#1abc9c", bold = true }, -- Cyan/Teal
        TodoSignINFO = { fg = "#0db9d7", bold = true }, -- Light Blue
        TodoSignPERF = { fg = "#bb9af7", bold = true }, -- Purple
        TodoSignXXX = { fg = "#f7768e", bold = true }, -- Red
    }

    for group, opts_tbl in pairs(highlights) do
        if vim.fn.hlexists(group) == 0 then
            vim.api.nvim_set_hl(0, group, opts_tbl)
        end
    end

    -- Set up keymap if configured
    if config.options.keymap then
        vim.keymap.set("n", config.options.keymap, "<cmd>TodoPicker<cr>", { desc = "Find Callouts" })
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

    -- Try to get treesitter parser for this buffer
    local ok, parser = pcall(vim.treesitter.get_parser, bufnr, vim.filetype.match({ buf = bufnr }))
    if not ok or not parser then
        return true -- If no treesitter, assume it's valid (fallback)
    end

    -- Get the syntax tree
    local trees = parser:parse()
    if not trees or #trees == 0 then
        return true
    end

    local root = trees[1]:root()
    
    -- Get the node at the position (convert to 0-indexed)
    local node = root:descendant_for_range(row - 1, col - 1, row - 1, col - 1)
    
    -- Walk up the tree to check if we're in a comment
    while node do
        local node_type = node:type()
        -- Check for common comment node types across different languages
        if node_type:match("comment") or node_type:match("doc") then
            return true
        end
        node = node:parent()
    end
    
    return false
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
