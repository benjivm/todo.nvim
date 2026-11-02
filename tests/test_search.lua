local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/helpers.lua")
local config = require("todo-nvim.config")
local search = require("todo-nvim.search")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({ hooks = { pre_case = H.reset } })

T["parse_rg_line"] = MiniTest.new_set()

T["parse_rg_line"]["parses a relative path"] = function()
    eq(search.parse_rg_line("./lua/a.lua:3:4:-- TODO: x", "/repo"), {
        filepath = "/repo/lua/a.lua",
        lnum = 3,
        col = 4,
        line = "-- TODO: x",
        text = "-- TODO: x",
        keyword = "TODO",
        word = "TODO",
    })
end

T["parse_rg_line"]["keeps colons in the text"] = function()
    local item = search.parse_rg_line("a.lua:1:4:-- FIXME: see a.lua:10:2: here", "/repo")
    eq({ item.filepath, item.lnum, item.col, item.text }, { "/repo/a.lua", 1, 4, "-- FIXME: see a.lua:10:2: here" })
    eq({ item.keyword, item.word }, { "FIX", "FIXME" })
end

T["parse_rg_line"]["handles Windows paths"] = function()
    local item = search.parse_rg_line([[C:\code\a.lua:12:10:x = 1 -- TODO: y:z]], "C:\\code")
    eq({ item.filepath, item.lnum, item.col, item.keyword }, { [[C:\code\a.lua]], 12, 10, "TODO" })
end

T["parse_rg_line"]["uses the keyword at the reported column"] = function()
    local line = "local BUG = 1 -- NOTE: here"
    eq(search.parse_rg_line("a.lua:1:7:" .. line, "/r").keyword, "BUG")
    eq(search.parse_rg_line("a.lua:1:18:" .. line, "/r").keyword, "NOTE")
end

T["parse_rg_line"]["strips CR and ignores junk"] = function()
    eq(search.parse_rg_line("a.lua:1:4:-- TODO\r", "/r").line, "-- TODO")
    eq(search.parse_rg_line("not rg output", "/r"), nil)
    eq(search.parse_rg_line("a.lua:1:1:no keyword here", "/r"), nil)
end

T["build_rg_command"] = MiniTest.new_set()

T["build_rg_command"]["passes the pattern with -e and paths after --"] = function()
    config.setup({ search_paths = { "src", "-weird" } })
    local cmd = search.build_rg_command()
    eq(vim.list_slice(cmd, #cmd - 2), { "--", "src", "-weird" })
    eq(vim.tbl_contains(cmd, "--case-sensitive"), true)
end

local function run_search(opts)
    local result
    search.search_todos(opts, function(items, root)
        result = { items = items, root = root }
    end)
    vim.wait(5000, function()
        return result ~= nil
    end)
    return result
end

T["search_todos"] = MiniTest.new_set({
    hooks = {
        pre_case = function()
            if vim.fn.executable("rg") == 0 then
                MiniTest.skip("rg not installed")
            end
        end,
    },
})

local function fixture_dir()
    local dir = vim.fn.tempname()
    vim.fn.mkdir(dir .. "/sub", "p")
    vim.fn.writefile({ "-- TODO: one", "local DEBUG = 1", "-- FIXME: two" }, dir .. "/a.lua")
    vim.fn.writefile({ "# NOTE: three" }, dir .. "/sub/b.py")
    return vim.uv.fs_realpath(dir)
end

T["search_todos"]["returns absolute, sorted items"] = function()
    local dir = fixture_dir()
    local result = run_search({ root = dir })
    eq(result.root, dir)
    eq(
        vim.tbl_map(function(i)
            return { i.filepath, i.lnum, i.keyword }
        end, result.items),
        {
            { dir .. "/a.lua", 1, "TODO" },
            { dir .. "/a.lua", 3, "FIX" },
            { dir .. "/sub/b.py", 1, "NOTE" },
        }
    )
end

T["search_todos"]["can be limited to keywords"] = function()
    local result = run_search({ root = fixture_dir(), keywords = { "FIX", "NOTE" } })
    eq(
        vim.tbl_map(function(i)
            return i.word
        end, result.items),
        { "FIXME", "NOTE" }
    )
end

T["search_todos"]["returns nothing for unknown keywords"] = function()
    eq(run_search({ root = fixture_dir(), keywords = { "NOPE" } }).items, {})
end

T["search_todos"]["reports rg errors"] = function()
    config.setup({ search_paths = { "does-not-exist" } })
    local notify, messages = vim.notify, {}
    vim.notify = function(msg)
        table.insert(messages, msg)
    end
    local result = run_search({ root = fixture_dir() })
    vim.notify = notify
    eq(result.items, {})
    eq(#messages, 1)
    eq(messages[1]:find("rg exited with code 2", 1, true) ~= nil, true)
end

return T
