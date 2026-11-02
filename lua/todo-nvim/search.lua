local config = require("todo-nvim.config")
local match = require("todo-nvim.match")

local M = {}

---@class todo.Item
---@field filepath string absolute path
---@field lnum integer 1-indexed line
---@field col integer 1-indexed byte column of the keyword
---@field line string the full line
---@field text string the line, trimmed
---@field keyword string keyword name, e.g. "FIX"
---@field word string matched text, e.g. "FIXME"

--- Directory to search from, based on `search_root`.
---@return string
function M.root()
    local cwd = assert(vim.uv.cwd())
    if config.get().search_root == "git" then
        return vim.fs.root(0, ".git") or cwd
    end
    return cwd
end

--- The rg command for the configured keywords and paths.
---@param keywords? string[] keyword names to limit the search to
---@return string[]
function M.build_rg_command(keywords)
    local cmd = {
        "rg",
        "--vimgrep",
        "--color=never",
        "--follow",
        "--case-sensitive",
        "-e",
        match.rg_pattern(keywords),
        "--",
    }
    return vim.list_extend(cmd, vim.deepcopy(config.get().search_paths))
end

local function is_absolute(path)
    return path:sub(1, 1) == "/" or path:find("^%a:[\\/]") ~= nil or path:sub(1, 2) == "\\\\"
end

--- Parse one line of `rg --vimgrep` output.
---@param line string `path:lnum:col:text`
---@param root string directory rg ran in; relative paths are joined to it
---@param words? string[] from match.words(), when the search was limited
---@return todo.Item|nil
function M.parse_rg_line(line, root, words)
    -- Non-greedy path so colons in the text don't end up in it. A Windows
    -- drive (`C:\`) is skipped because `\` isn't a digit.
    local path, lnum, col, text = line:match("^(.-):(%d+):(%d+):(.*)$")
    if not path then
        return nil
    end
    text = text:gsub("\r$", "")
    col = tonumber(col)

    -- Use the keyword at the column rg reports
    local found
    for _, m in ipairs(match.find(text, words)) do
        if m.start_col == col - 1 then
            found = m
            break
        end
    end
    if not found then
        return nil
    end

    if not is_absolute(path) then
        path = vim.fs.joinpath(root, (path:gsub("^%.[\\/]", "")))
    end

    return {
        filepath = path,
        lnum = tonumber(lnum),
        col = col,
        line = text,
        text = vim.trim(text),
        keyword = found.keyword,
        word = found.word,
    }
end

--- Parse full rg output into items sorted by file, line and column.
---@return todo.Item[]
function M.parse_rg_output(stdout, root, words)
    local items = {}
    for line in vim.gsplit(stdout or "", "\n", { plain = true, trimempty = true }) do
        local item = M.parse_rg_line(line, root, words)
        if item then
            table.insert(items, item)
        end
    end
    table.sort(items, function(a, b)
        if a.filepath ~= b.filepath then
            return a.filepath < b.filepath
        end
        if a.lnum ~= b.lnum then
            return a.lnum < b.lnum
        end
        return a.col < b.col
    end)
    return items
end

---@class todo.SearchOpts
---@field keywords? string[] keyword names to limit the search to
---@field root? string directory to search from, defaults to M.root()

--- Search for keywords with rg. The callback runs on the main loop with
--- every match (not yet filtered to comments). It is not called when rg
--- is missing or fails to start.
---@param opts? todo.SearchOpts
---@param callback fun(items: todo.Item[], root: string)
function M.search_todos(opts, callback)
    if type(opts) == "function" then
        opts, callback = {}, opts
    end
    opts = opts or {}

    if vim.fn.executable("rg") == 0 then
        vim.notify("todo-nvim: ripgrep (rg) is not installed or not in $PATH", vim.log.levels.ERROR)
        return
    end

    local root = opts.root or M.root()
    local words = opts.keywords and match.words(opts.keywords) or nil
    if words and #words == 0 then
        vim.schedule(function()
            callback({}, root)
        end)
        return
    end

    local ok, err = pcall(vim.system, M.build_rg_command(opts.keywords), { text = true, cwd = root }, function(obj)
        vim.schedule(function()
            -- 1 means no matches. 2 means an error, but rg still prints the
            -- matches it found (e.g. when some files are unreadable).
            if obj.code ~= 0 and obj.code ~= 1 then
                local msg = vim.trim(obj.stderr or "")
                vim.notify(
                    ("todo-nvim: rg exited with code %d%s"):format(obj.code, msg ~= "" and (":\n" .. msg) or ""),
                    vim.log.levels.ERROR
                )
            end
            callback(M.parse_rg_output(obj.stdout, root, words), root)
        end)
    end)
    if not ok then
        vim.notify("todo-nvim: failed to run rg: " .. tostring(err), vim.log.levels.ERROR)
    end
end

return M
