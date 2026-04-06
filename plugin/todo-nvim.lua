vim.api.nvim_create_user_command("TodoPicker", function()
    require("todo-nvim").show()
end, {
    desc = "Show TODOs in picker",
})
