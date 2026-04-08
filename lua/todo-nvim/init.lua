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
            signs.refresh_buffer(ev.buf)
        end,
    })
end

-- Main command to show callouts
function M.show()
    search.search_todos(function(todos)
        vim.schedule(function()
            if #todos == 0 then
                vim.notify("No callouts found", vim.log.levels.INFO)
                return
            end

            picker.show(todos)
        end)
    end)
end

return M
