local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/helpers.lua")
local filter = require("todo-nvim.filter")
local search = require("todo-nvim.search")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
    hooks = {
        pre_case = H.reset,
        post_case = function()
            vim.cmd("silent! %bwipeout!")
        end,
    },
})

--- Write files to a temp dir and return fake rg items for every keyword.
local function items_for(files)
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir, "p")
    local out = {}
    for name, lines in pairs(files) do
        vim.fn.writefile(lines, dir .. "/" .. name)
        for lnum, line in ipairs(lines) do
            for _, m in ipairs(require("todo-nvim.match").find(line)) do
                table.insert(out, ("%s:%d:%d:%s"):format(name, lnum, m.start_col + 1, line))
            end
        end
    end
    return search.parse_rg_output(table.concat(out, "\n"), dir), dir
end

local function run(items, comments)
    local result
    filter.filter(items, { comments = comments }, function(r)
        result = r
    end)
    vim.wait(5000, function()
        return result ~= nil
    end)
    return vim.tbl_map(function(i)
        return { vim.fs.basename(i.filepath), i.lnum, i.word }
    end, result)
end

local files = {
    ["a.lua"] = { "local TODO_LIST = {} -- TODO: x", 'local s = "FIX"', "-- NOTE: and BUG" },
    ["b.md"] = { "# TODO list", "<!-- just text -->" },
    ["c.yaml"] = { "key: TODO # FIXME" },
}

T["keeps the leftmost comment keyword per line"] = function()
    eq(run(items_for(files), true), {
        { "a.lua", 1, "TODO" },
        { "a.lua", 3, "NOTE" },
        { "c.yaml", 1, "FIXME" },
    })
end

T["keeps every line without comment filtering"] = function()
    eq(run(items_for(files), false), {
        { "a.lua", 1, "TODO" },
        { "a.lua", 2, "FIX" },
        { "a.lua", 3, "NOTE" },
        { "b.md", 1, "TODO" },
        { "c.yaml", 1, "TODO" },
    })
end

T["does not create buffers"] = function()
    local items = items_for(files)
    local before = #vim.api.nvim_list_bufs()
    run(items, true)
    eq(#vim.api.nvim_list_bufs(), before)
end

T["uses a loaded buffer"] = function()
    local items, dir = items_for({ ["a.lua"] = { "x = 1 -- TODO" } })
    vim.cmd.edit(vim.fn.fnameescape(dir .. "/a.lua"))
    -- Pretend the parser disagrees with the file: the buffer's tree is used
    vim.bo.filetype = "c"
    eq(run(items, true), {})
end

T["spreads work over event-loop ticks"] = function()
    local many = {}
    for i = 1, 30 do
        many["f" .. i .. ".lua"] = { "-- TODO: " .. i }
    end
    local items = items_for(many)
    local budget = filter.budget_ms
    filter.budget_ms = 0
    local result
    filter.filter(items, { comments = true }, function(r)
        result = r
    end)
    eq(result, nil)
    vim.wait(5000, function()
        return result ~= nil
    end)
    filter.budget_ms = budget
    eq(#result, 30)
end

return T
