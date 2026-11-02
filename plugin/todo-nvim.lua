if vim.g.loaded_todo_nvim then
    return
end
vim.g.loaded_todo_nvim = true

if vim.fn.has("nvim-0.10") == 0 then
    vim.notify("todo-nvim requires Neovim 0.10 or later", vim.log.levels.ERROR)
    return
end

vim.api.nvim_create_user_command("TodoPicker", function()
    require("todo-nvim").show()
end, {
    desc = "Show todos in a picker",
})

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
