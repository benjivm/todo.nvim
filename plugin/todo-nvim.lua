if vim.g.loaded_todo_nvim then
    return
end
vim.g.loaded_todo_nvim = true

if vim.fn.has("nvim-0.10") == 0 then
    vim.notify("todo-nvim requires Neovim 0.10 or later", vim.log.levels.ERROR)
    return
end

local function list_command(name, fn_name, desc)
    vim.api.nvim_create_user_command(name, function(cmd)
        local todo = require("todo-nvim")
        local keywords, err = todo.parse_keywords(cmd.fargs)
        if err then
            vim.notify(err, vim.log.levels.ERROR)
            return
        end
        todo[fn_name]({ keywords = keywords })
    end, {
        desc = desc,
        nargs = "*",
        complete = function(arglead)
            return require("todo-nvim").complete_keywords(arglead)
        end,
    })
end

list_command("TodoPicker", "show", "Show todos in a picker")
list_command("TodoQuickfix", "quickfix", "Put todos in the quickfix list")
list_command("TodoLocList", "loclist", "Put todos in the location list")

vim.api.nvim_create_user_command("TodoSigns", function(cmd)
    local signs = require("todo-nvim.signs")
    local arg = cmd.fargs[1] or "toggle"
    if arg == "on" then
        signs.set_enabled(true)
    elseif arg == "off" then
        signs.set_enabled(false)
    elseif arg == "toggle" then
        signs.toggle()
    else
        vim.notify("Usage: :TodoSigns [on|off|toggle]", vim.log.levels.ERROR)
    end
end, {
    desc = "Turn todo signs on or off",
    nargs = "?",
    complete = function()
        return { "on", "off", "toggle" }
    end,
})
