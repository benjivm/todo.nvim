local config = require("todo-nvim.config")

local M = {}

-- Escape special regex characters for ripgrep
local function escape_regex(str)
    return str:gsub("[%(%)%.%+%-%*%?%[%]%^%$%\\]", "\\%1")
end

-- Build ripgrep command to search for TODOs
function M.build_rg_command()
    local opts = config.options

    -- Build keyword pattern with appropriate word boundaries
    local patterns = {}
    for _, keyword in ipairs(opts.keywords) do
        local escaped = escape_regex(keyword)
        local pattern = escaped

        -- Add word boundary at start if keyword starts with word character
        if keyword:match("^%w") then
            pattern = "\\b" .. pattern
        end

        -- Add word boundary at end if keyword ends with word character
        if keyword:match("%w$") then
            pattern = pattern .. "\\b"
        end

        table.insert(patterns, pattern)
    end
    local keyword_pattern = string.format("(%s)", table.concat(patterns, "|"))

    local cmd = {
        "rg",
        "--vimgrep",
        "--no-heading",
        "--smart-case",
        "--color=never",
        "--follow",
    }

    -- Add search pattern
    table.insert(cmd, keyword_pattern)

    -- Add search paths
    vim.list_extend(cmd, opts.search_paths)

    return cmd
end

-- Parse ripgrep output line
function M.parse_rg_line(line)
    -- Format: filepath:line:col:text
    local filepath, lnum, col, text = line:match("^(.+):(%d+):(%d+):(.*)$")

    if not filepath then
        return nil
    end

    -- Extract which keyword was matched
    local keyword = nil
    for _, kw in ipairs(config.options.keywords) do
        if text:find(kw, 1, true) then
            keyword = kw
            break
        end
    end

    return {
        filepath = filepath,
        lnum = tonumber(lnum),
        col = tonumber(col),
        text = vim.trim(text),
        keyword = keyword or "TODO",
    }
end

-- Search for all TODOs in the codebase
function M.search_todos(callback)
    local cmd = M.build_rg_command()
    local results = {}

    local function on_exit(obj)
        callback(results)
    end

    local stdout = vim.loop.new_pipe(false)
    local stderr = vim.loop.new_pipe(false)

    local handle
    handle = vim.loop.spawn(
        cmd[1],
        {
            args = vim.list_slice(cmd, 2),
            stdio = { nil, stdout, stderr },
            cwd = vim.fn.getcwd(),
        },
        vim.schedule_wrap(function(code, signal)
            stdout:close()
            stderr:close()
            handle:close()
            on_exit({ code = code, signal = signal })
        end)
    )

    if not handle then
        callback({})
        return
    end

    stdout:read_start(function(err, data)
        assert(not err, err)
        if data then
            for line in data:gmatch("[^\n]+") do
                local parsed = M.parse_rg_line(line)
                if parsed then
                    table.insert(results, parsed)
                end
            end
        end
    end)

    -- Consume stderr to prevent blocking
    stderr:read_start(function(err, data) end)
end

return M
