local H = {}

H.root = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")

--- Create a named, listed buffer with the given lines and filetype.
function H.make_buf(lines, filetype, name)
    local bufnr = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_buf_set_name(bufnr, name or (vim.fn.tempname() .. "." .. (filetype or "txt")))
    vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
    vim.bo[bufnr].filetype = filetype or ""
    return bufnr
end

function H.has_parser(lang)
    local ok, parser = pcall(vim.treesitter.get_string_parser, "", lang)
    return ok and parser ~= nil
end

function H.reset()
    local config = require("todo-nvim.config")
    config.options = nil
    config.lookup = {}
end

return H
