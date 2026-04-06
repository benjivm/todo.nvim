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

-- Place signs for todos
function M.place_signs(todos)
    -- Clear all existing signs
    M.clear_signs()

    -- Group todos by buffer
    local buffers = {}
    for _, todo in ipairs(todos) do
        local bufnr = vim.fn.bufnr(todo.filepath)

        -- Only place signs if buffer is loaded
        if bufnr ~= -1 then
            if not buffers[bufnr] then
                buffers[bufnr] = {}
            end
            table.insert(buffers[bufnr], todo)
        end
    end

    -- Place signs for each buffer
    for bufnr, buffer_todos in pairs(buffers) do
        for _, todo in ipairs(buffer_todos) do
            vim.fn.sign_place(0, "todo-nvim", "TodoSign", bufnr, {
                lnum = todo.lnum,
                priority = 10,
            })
        end
    end
end

-- Clear all signs
function M.clear_signs()
    vim.fn.sign_unplace("todo-nvim")
end

-- Refresh signs (search and place)
function M.refresh()
    local search = require("todo-nvim.search")
    search.search_todos(function(todos)
        vim.schedule(function()
            M.place_signs(todos)
        end)
    end)
end

return M
