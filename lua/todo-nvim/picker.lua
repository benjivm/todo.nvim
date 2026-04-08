local M = {}

-- Snacks picker
function M.show(todos)
    local ok, snacks = pcall(require, "snacks")
    if not ok then
        vim.notify("Snacks not found", vim.log.levels.ERROR)
        return
    end

    local config = require("todo-nvim.config")

    -- Convert todos to snacks picker items format
    local items = {}
    for _, todo in ipairs(todos) do
        table.insert(items, {
            text = todo.text,
            file = todo.filepath,
            pos = { todo.lnum, todo.col },
            keyword = todo.keyword,
        })
    end

    -- Create picker with snacks
    snacks.picker.pick({
        source = "todo",
        title = "Callouts",
        items = items,
        format = function(item)
            local file_path = vim.fn.fnamemodify(item.file, ":.")
            -- Get the highlight group for this keyword
            local hl_group = config.options.highlights[item.keyword] or "TodoSignTODO"

            return {
                { file_path .. ":", "Comment" },
                { tostring(item.pos[1]), "LineNr" },
                { ":", "Comment" },
                { tostring(item.pos[2]), "LineNr" },
                { ": [", "Comment" },
                { item.keyword, hl_group },
                { "] ", "Comment" },
                { item.text, "Normal" },
            }
        end,
        preview = "file",
    })
end

return M
