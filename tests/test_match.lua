local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/helpers.lua")
local config = require("todo-nvim.config")
local match = require("todo-nvim.match")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({ hooks = { pre_case = H.reset } })

local function words(line)
    return vim.tbl_map(function(m)
        return m.word
    end, match.find(line))
end

T["find"] = MiniTest.new_set()

T["find"]["respects word boundaries"] = function()
    eq(words("DEBUG PREFIX TODOS XTODO TODO_LIST FIX_ME"), {})
    eq(words("-- BUG: x"), { "BUG" })
    eq(words("(FIX)"), { "FIX" })
    eq(words("FIXME"), { "FIXME" })
end

T["find"]["matches @todo without a leading boundary"] = function()
    eq(words("x@todo y"), { "@todo" })
    eq(words("@todos"), {})
end

T["find"]["is case sensitive"] = function()
    eq(words("todo Todo fixme"), {})
end

T["find"]["returns every match in column order"] = function()
    local found = match.find("// NOTE: TODO and FIXME, then TODO")
    eq(
        vim.tbl_map(function(m)
            return { m.keyword, m.word, m.start_col, m.end_col }
        end, found),
        {
            { "NOTE", "NOTE", 3, 7 },
            { "TODO", "TODO", 9, 13 },
            { "FIX", "FIXME", 18, 23 },
            { "TODO", "TODO", 30, 34 },
        }
    )
end

T["find"]["keeps the longest of overlapping matches"] = function()
    config.setup({ keywords = { ["TODO(me)"] = { icon = "T" } } })
    eq(words("TODO(me) x"), { "TODO(me)" })
end

T["find"]["can be limited to keywords"] = function()
    eq(
        vim.tbl_map(function(m)
            return m.word
        end, match.find("TODO FIXME BUG", match.words({ "FIX" }))),
        { "FIXME" }
    )
end

T["rg_pattern"] = MiniTest.new_set()

T["rg_pattern"]["matches the same words as find"] = function()
    if vim.fn.executable("rg") == 0 then
        MiniTest.skip("rg not installed")
    end
    config.setup({ keywords = { ["TODO(me)"] = { icon = "T" }, ["a.b"] = { icon = "." } } })
    local lines = {
        "DEBUG PREFIX TODOS XTODO TODO_LIST",
        "-- TODO: x",
        "x@todo y",
        "éTODO TODOé",
        "FIXME: and BUG",
        "TODO(me) here",
        "a.b axb",
    }
    local file = vim.fn.tempname()
    vim.fn.writefile(lines, file)
    local out =
        vim.system({ "rg", "--only-matching", "--no-filename", "--case-sensitive", "-e", match.rg_pattern(), file })
            :wait()
    local expected = {}
    for _, line in ipairs(lines) do
        vim.list_extend(expected, words(line))
    end
    eq(vim.split(vim.trim(out.stdout), "\n"), expected)
end

T["rg_pattern"]["can be limited to keywords"] = function()
    eq(match.rg_pattern({ "FIX" }), "(?-u:\\b)FIXME(?-u:\\b)|(?-u:\\b)FIX(?-u:\\b)")
end

T["in_comment"] = MiniTest.new_set()

local function comment_cols(bufnr)
    local result = {}
    for row, line in ipairs(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)) do
        for _, m in ipairs(match.find(line)) do
            table.insert(result, { row, m.word, match.in_comment(bufnr, row - 1, m.start_col) })
        end
    end
    return result
end

T["in_comment"]["lua"] = function()
    local bufnr = H.make_buf({
        "local TODO_LIST = {} -- TODO: x",
        'local s = "FIX this"',
        "--[[ NOTE: block ]]",
        "local BUG = 1",
    }, "lua")
    eq(comment_cols(bufnr), {
        { 1, "TODO", true },
        { 2, "FIX", false },
        { 3, "NOTE", true },
        { 4, "BUG", false },
    })
end

T["in_comment"]["c"] = function()
    local bufnr = H.make_buf({
        "int TODO = 1; // TODO: x",
        "/* FIXME: block */",
        'char *s = "BUG";',
    }, "c")
    eq(comment_cols(bufnr), {
        { 1, "TODO", false },
        { 1, "TODO", true },
        { 2, "FIXME", true },
        { 3, "BUG", false },
    })
end

T["in_comment"]["typescript"] = function()
    if not H.has_parser("typescript") then
        MiniTest.skip("no typescript parser")
    end
    local bufnr = H.make_buf({ "const TODO = 1; // TODO: x", "/** FIXME */" }, "typescript")
    eq(comment_cols(bufnr), { { 1, "TODO", false }, { 1, "TODO", true }, { 2, "FIXME", true } })
end

T["in_comment"]["markdown text is not a comment"] = function()
    local bufnr = H.make_buf({ "# TODO list", "", "- TODO: write docs" }, "markdown")
    eq(comment_cols(bufnr), { { 1, "TODO", false }, { 3, "TODO", false } })
end

T["in_comment"]["yaml values are not comments"] = function()
    local bufnr = H.make_buf({ "key: TODO", "# TODO: x" }, "yaml")
    eq(comment_cols(bufnr), { { 1, "TODO", false }, { 2, "TODO", true } })
end

T["in_comment"]["falls back to commentstring without a parser"] = function()
    local bufnr = H.make_buf({ "x = TODO  ; FIX: y" }, "nope")
    vim.bo[bufnr].commentstring = "; %s"
    eq(comment_cols(bufnr), { { 1, "TODO", false }, { 1, "FIX", true } })
end

T["in_comment"]["accepts everything without parser or commentstring"] = function()
    local bufnr = H.make_buf({ "TODO" }, "")
    vim.bo[bufnr].commentstring = ""
    eq(comment_cols(bufnr), { { 1, "TODO", true } })
end

T["file_checker"] = MiniTest.new_set()

T["file_checker"]["parses text without creating a buffer"] = function()
    local text = "local TODO = 1 -- TODO: x"
    local before = #vim.api.nvim_list_bufs()
    local check = match.file_checker("/tmp/x.lua", function()
        return text
    end, function()
        return text
    end)
    eq({ check(0, 6), check(0, 18) }, { false, true })
    eq(#vim.api.nvim_list_bufs(), before)
end

T["file_checker"]["uses the filetype commentstring as a fallback"] = function()
    local line = "key: TODO # FIX"
    local check = match.file_checker("/tmp/x.yaml", function()
        return line
    end, function()
        return line
    end)
    eq({ check(0, 5), check(0, 12) }, { false, true })
end

return T
