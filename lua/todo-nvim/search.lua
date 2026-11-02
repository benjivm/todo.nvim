local config = require("todo-nvim.config")
local match = require("todo-nvim.match")

local M = {}

-- Build ripgrep command to search for TODOs
function M.build_rg_command()
    local opts = config.get()
    local keyword_pattern = match.rg_pattern()

    local cmd = {
        "rg",
        "--vimgrep",
        "--no-heading",
        "--case-sensitive",
        "--color=never",
        "--follow",
    }

    -- Add search pattern
    vim.list_extend(cmd, { "-e", keyword_pattern, "--" })

    -- Add search paths
    vim.list_extend(cmd, opts.search_paths)

    return cmd
end

-- Parse ripgrep output line
function M.parse_rg_line(line)
    -- Format: filepath:line:col:text
    local filepath, lnum, col, text = line:match("^(.-):(%d+):(%d+):(.*)$")

    if not filepath then
        return nil
    end

    -- Use the keyword at the column rg reports
    local keyword
    for _, m in ipairs(match.find(text)) do
        if m.start_col == tonumber(col) - 1 then
            keyword = m.keyword
            break
        end
    end
    if not keyword then
        return nil
    end

    return {
        filepath = filepath,
        lnum = tonumber(lnum),
        col = tonumber(col),
        text = vim.trim(text),
        keyword = keyword,
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
