local match = require("todo-nvim.match")

local M = {}

-- Time to spend per event-loop tick before yielding to the UI
M.budget_ms = 10

-- Files larger than this are not parsed; the 'commentstring' fallback is used
M.max_parse_bytes = 1024 * 1024

local function read_file(path)
    local stat = vim.uv.fs_stat(path)
    if not stat or stat.size > M.max_parse_bytes then
        return nil
    end
    local f = io.open(path, "rb")
    if not f then
        return nil
    end
    local text = f:read("*a")
    f:close()
    return text
end

local function realpath(path)
    return vim.fs.normalize(vim.uv.fs_realpath(path) or path)
end

--- Loaded buffers by real path. Buffer names have symlinks resolved, rg
--- paths may not.
local function loaded_buffers()
    local bufs = {}
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        local name = vim.api.nvim_buf_get_name(bufnr)
        if name ~= "" and vim.api.nvim_buf_is_loaded(bufnr) then
            bufs[realpath(name)] = bufnr
        end
    end
    return bufs
end

---@param items todo.Item[] all from the same file
---@return todo.CommentChecker
local function checker_for(path, items, buffers)
    local bufnr = buffers[realpath(path)]
    -- rg read the file on disk, so a modified buffer's tree may not line up
    if bufnr and not vim.bo[bufnr].modified then
        return match.buf_checker(bufnr)
    end
    local lines = {}
    for _, item in ipairs(items) do
        lines[item.lnum - 1] = item.line
    end
    return match.file_checker(path, function()
        return read_file(path)
    end, function(row)
        return lines[row]
    end)
end

--- Keep the first item on each line that passes `keep`. If `keep` errors,
--- every item of the file is kept.
local function filter_file(items, keep)
    local result, seen = {}, {}
    local ok = pcall(function()
        for _, item in ipairs(items) do
            if not seen[item.lnum] and keep(item) then
                seen[item.lnum] = true
                table.insert(result, item)
            end
        end
    end)
    if not ok then
        result, seen = {}, {}
        for _, item in ipairs(items) do
            if not seen[item.lnum] then
                seen[item.lnum] = true
                table.insert(result, item)
            end
        end
    end
    return result
end

--- Group items (sorted by file) by file, keeping the order.
local function group_by_file(items)
    local files = {}
    for _, item in ipairs(items) do
        local last = files[#files]
        if not last or last.path ~= item.filepath then
            last = { path = item.filepath, items = {} }
            table.insert(files, last)
        end
        table.insert(last.items, item)
    end
    return files
end

--- Filter rg results to one item per line: the leftmost keyword, and with
--- `comments` only keywords inside comments. Files are parsed at most once,
--- without creating buffers, spread over event-loop ticks.
---@param items todo.Item[] sorted by file, line and column
---@param opts { comments: boolean }
---@param callback fun(items: todo.Item[])
function M.filter(items, opts, callback)
    local files = group_by_file(items)
    local result = {}

    if not opts.comments then
        for _, file in ipairs(files) do
            vim.list_extend(
                result,
                filter_file(file.items, function()
                    return true
                end)
            )
        end
        callback(result)
        return
    end

    local buffers = loaded_buffers()
    local i = 0
    local function step()
        local start = vim.uv.hrtime()
        repeat
            i = i + 1
            local file = files[i]
            local ok, check = pcall(checker_for, file.path, file.items, buffers)
            vim.list_extend(
                result,
                filter_file(file.items, function(item)
                    return not ok or check(item.lnum - 1, item.col - 1)
                end)
            )
        until i >= #files or (vim.uv.hrtime() - start) / 1e6 > M.budget_ms

        if i < #files then
            vim.schedule(step)
        else
            callback(result)
        end
    end

    if #files == 0 then
        callback(result)
    else
        step()
    end
end

return M
