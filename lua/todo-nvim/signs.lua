local config = require("todo-nvim.config")
local match = require("todo-nvim.match")

local M = {}

M.ns = vim.api.nvim_create_namespace("todo-nvim")

-- Above this many lines, only the visible part of a buffer is scanned
M.large_file_lines = 10000

-- nil follows the `signs` option; :TodoSigns sets it
local enabled = nil

---@type table<integer, uv.uv_timer_t>
local timers = {}

function M.is_enabled()
    if enabled == nil then
        return config.get().signs
    end
    return enabled
end

local function should_scan(bufnr)
    return vim.api.nvim_buf_is_loaded(bufnr) and vim.bo[bufnr].buftype == "" and vim.api.nvim_buf_get_name(bufnr) ~= ""
end

local function is_large(bufnr)
    return vim.api.nvim_buf_line_count(bufnr) > M.large_file_lines
end

--- Visible rows of a buffer across its windows, as merged 0-indexed,
--- end-exclusive ranges.
local function visible_ranges(bufnr)
    local ranges = {}
    for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
        local first, last = unpack(vim.api.nvim_win_call(win, function()
            return { vim.fn.line("w0"), vim.fn.line("w$") }
        end))
        table.insert(ranges, { first - 1, last })
    end
    table.sort(ranges, function(a, b)
        return a[1] < b[1]
    end)
    local merged = {}
    for _, r in ipairs(ranges) do
        local prev = merged[#merged]
        if prev and r[1] <= prev[2] then
            prev[2] = math.max(prev[2], r[2])
        else
            table.insert(merged, r)
        end
    end
    return merged
end

---@class todo.BufTodo
---@field row integer 0-indexed
---@field match todo.Match

--- Find the leftmost keyword in a comment on each line.
---@param bufnr integer
---@param first? integer 0-indexed first row
---@param last? integer 0-indexed, end-exclusive
---@return todo.BufTodo[]
function M.scan(bufnr, first, last)
    first = first or 0
    last = last or vim.api.nvim_buf_line_count(bufnr)
    local lines = vim.api.nvim_buf_get_lines(bufnr, first, last, false)
    local in_comment ---@type todo.CommentChecker?
    local todos = {}
    for i, line in ipairs(lines) do
        local row = first + i - 1
        for _, m in ipairs(match.find(line)) do
            -- Only parse when a line has a keyword
            in_comment = in_comment or match.buf_checker(bufnr, first, last)
            if in_comment(row, m.start_col) then
                table.insert(todos, { row = row, match = m })
                break
            end
        end
    end
    return todos
end

--- Clear and redraw the signs and keyword highlights of a buffer.
---@param bufnr? integer
function M.refresh(bufnr)
    bufnr = (bufnr == nil or bufnr == 0) and vim.api.nvim_get_current_buf() or bufnr
    if not vim.api.nvim_buf_is_valid(bufnr) then
        return
    end
    vim.api.nvim_buf_clear_namespace(bufnr, M.ns, 0, -1)
    if not M.is_enabled() or not should_scan(bufnr) then
        return
    end

    local ranges = is_large(bufnr) and visible_ranges(bufnr) or { { 0, vim.api.nvim_buf_line_count(bufnr) } }
    local lookup = config.get_lookup()
    for _, range in ipairs(ranges) do
        for _, todo in ipairs(M.scan(bufnr, range[1], range[2])) do
            local kw = lookup[todo.match.word]
            vim.api.nvim_buf_set_extmark(bufnr, M.ns, todo.row, todo.match.start_col, {
                end_col = todo.match.end_col,
                hl_group = kw.hl,
                sign_text = kw.icon,
                sign_hl_group = kw.hl,
                priority = 10,
            })
        end
    end
end

--- Refresh a buffer after a delay, restarting the delay on each call.
---@param bufnr integer
---@param delay? integer ms, defaults to `debounce_ms`
function M.schedule_refresh(bufnr, delay)
    local timer = timers[bufnr]
    if not timer then
        timer = assert(vim.uv.new_timer())
        timers[bufnr] = timer
    end
    timer:stop()
    timer:start(
        delay or config.get().debounce_ms,
        0,
        vim.schedule_wrap(function()
            M.refresh(bufnr)
        end)
    )
end

--- Stop a buffer's refresh timer.
function M.detach(bufnr)
    local timer = timers[bufnr]
    if timer then
        timer:stop()
        timer:close()
        timers[bufnr] = nil
    end
end

local function refresh_all()
    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(bufnr) then
            M.refresh(bufnr)
        end
    end
end

--- Turn signs on or off for all buffers.
---@param value boolean
function M.set_enabled(value)
    enabled = value
    refresh_all()
end

function M.toggle()
    M.set_enabled(not M.is_enabled())
end

--- Create the autocmds that keep signs up to date.
function M.setup()
    local group = vim.api.nvim_create_augroup("TodoNvimSigns", { clear = true })

    vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType", "BufWritePost" }, {
        group = group,
        callback = function(ev)
            -- No delay, but still coalesce events that fire together
            M.schedule_refresh(ev.buf, 0)
        end,
    })

    vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
        group = group,
        callback = function(ev)
            M.schedule_refresh(ev.buf)
        end,
    })

    vim.api.nvim_create_autocmd("WinScrolled", {
        group = group,
        callback = function()
            -- Large buffers only show signs in the visible range
            for win in pairs(vim.v.event) do
                local winid = tonumber(win)
                if winid and vim.api.nvim_win_is_valid(winid) then
                    local bufnr = vim.api.nvim_win_get_buf(winid)
                    if is_large(bufnr) then
                        M.schedule_refresh(bufnr)
                    end
                end
            end
        end,
    })

    vim.api.nvim_create_autocmd("BufWipeout", {
        group = group,
        callback = function(ev)
            M.detach(ev.buf)
        end,
    })

    for _, win in ipairs(vim.api.nvim_list_wins()) do
        M.refresh(vim.api.nvim_win_get_buf(win))
    end
end

--- Move the cursor to the next (dir = 1) or previous (dir = -1) todo in the
--- current buffer. Uses the placed signs, so signs must be enabled.
---@param dir 1|-1
function M.jump(dir)
    local bufnr = vim.api.nvim_get_current_buf()
    local marks = vim.api.nvim_buf_get_extmarks(bufnr, M.ns, 0, -1, {})
    if #marks == 0 then
        vim.notify("No todos in buffer", vim.log.levels.INFO)
        return
    end

    local cursor = vim.api.nvim_win_get_cursor(0)
    local row, col = cursor[1] - 1, cursor[2]
    local target
    for _ = 1, vim.v.count1 do
        local found
        if dir > 0 then
            for _, mark in ipairs(marks) do
                if mark[2] > row or (mark[2] == row and mark[3] > col) then
                    found = mark
                    break
                end
            end
            found = found or (vim.o.wrapscan and marks[1] or nil)
        else
            for i = #marks, 1, -1 do
                local mark = marks[i]
                if mark[2] < row or (mark[2] == row and mark[3] < col) then
                    found = mark
                    break
                end
            end
            found = found or (vim.o.wrapscan and marks[#marks] or nil)
        end
        if not found then
            break
        end
        target, row, col = found, found[2], found[3]
    end

    if target then
        vim.cmd("normal! m'")
        vim.api.nvim_win_set_cursor(0, { target[2] + 1, target[3] })
    end
end

return M
