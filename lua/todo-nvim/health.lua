local M = {}

local function has_parser(lang)
    local ok, parser = pcall(vim.treesitter.get_string_parser, "", lang)
    return ok and parser ~= nil
end

function M.check()
    local health = vim.health
    local config = require("todo-nvim.config")

    health.start("todo-nvim")

    local version = tostring(vim.version())
    if vim.fn.has("nvim-0.10") == 1 then
        health.ok("Neovim " .. version)
    else
        health.error("Neovim 0.10 or later is required, found " .. version)
    end

    if vim.fn.executable("rg") == 1 then
        local result = vim.system({ "rg", "--version" }, { text = true }):wait()
        local first = vim.split(result.stdout or "", "\n")[1]
        health.ok(first ~= "" and first or "rg is executable")
    else
        health.error("ripgrep (rg) not found in $PATH", { "Install ripgrep: https://github.com/BurntSushi/ripgrep" })
    end

    if pcall(require, "snacks") then
        health.ok("snacks.nvim found")
    else
        health.warn("snacks.nvim not found", { ":TodoPicker falls back to vim.ui.select" })
    end

    if has_parser("comment") then
        health.info("Treesitter `comment` parser found")
    else
        health.info("Treesitter `comment` parser not installed (optional)")
    end

    local errors = config.validate(config.user_opts or {})
    if #errors == 0 then
        health.ok("Config is valid")
    else
        for _, err in ipairs(errors) do
            health.error("Config: " .. err)
        end
    end

    local ok, autocmds = pcall(vim.api.nvim_get_autocmds, { group = "TodoNvimSigns" })
    if ok and #autocmds > 0 then
        health.ok("setup() called, signs are " .. (require("todo-nvim.signs").is_enabled() and "on" or "off"))
    else
        health.info("setup() has not been called, so signs are not shown")
    end
end

return M
