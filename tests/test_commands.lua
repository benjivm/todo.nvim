local H = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h") .. "/helpers.lua")
local todo = require("todo-nvim")
local picker = require("todo-nvim.picker")
local eq = MiniTest.expect.equality

local cwd
local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            H.reset()
            cwd = vim.uv.cwd()
            local dir = vim.fn.tempname()
            vim.fn.mkdir(dir .. "/sub", "p")
            vim.fn.writefile({ "-- TODO: one", "local DEBUG = 1", "-- FIXME: two" }, dir .. "/a.lua")
            vim.fn.writefile({ "/* NOTE: three */" }, dir .. "/sub/b.c")
            vim.cmd.cd(dir)
        end,
        post_case = function()
            vim.cmd.cd(cwd)
            vim.cmd("stopinsert")
            vim.cmd("silent! cclose | silent! lclose | silent! %bwipeout!")
        end,
    },
})

local function wait_for(fn)
    return vim.wait(5000, fn)
end

local function qf_summary(list)
    return vim.tbl_map(function(e)
        return { vim.fs.basename(vim.api.nvim_buf_get_name(e.bufnr)), e.lnum, e.col }
    end, list)
end

T["parse_keywords"] = function()
    eq(todo.parse_keywords({}), nil)
    eq(todo.parse_keywords({ "TODO,FIXME", "FIX", "NOTE" }), { "TODO", "FIX", "NOTE" })
    local names, err = todo.parse_keywords({ "TODO,NOPE" })
    eq({ names, err }, { nil, 'Unknown keyword "NOPE"' })
end

T["complete_keywords"] = function()
    eq(todo.complete_keywords("F"), { "FIX" })
    eq(todo.complete_keywords("TODO,b"), { "TODO,BUG" })
    eq(#todo.complete_keywords("TODO,"), 7)
    eq(vim.fn.getcompletion("TodoQuickfix NO", "cmdline"), { "NOTE" })
end

T["relative paths"] = function()
    eq(picker.relative("/r/a/b.lua", "/r"), "a/b.lua")
    eq(picker.relative("/r/a/b.lua", "/r/"), "a/b.lua")
    eq(picker.relative("/other/b.lua", "/r"), "/other/b.lua")
end

T[":TodoQuickfix works without setup()"] = function()
    vim.cmd("TodoQuickfix")
    eq(
        wait_for(function()
            return #vim.fn.getqflist() == 3
        end),
        true
    )
    eq(qf_summary(vim.fn.getqflist()), { { "a.lua", 1, 4 }, { "a.lua", 3, 4 }, { "b.c", 1, 4 } })
    eq(vim.fn.getqflist({ title = 1 }).title, "Todos")
end

T[":TodoLocList filters keywords"] = function()
    vim.cmd("TodoLocList FIX,NOTE")
    eq(
        wait_for(function()
            return #vim.fn.getloclist(0) == 2
        end),
        true
    )
end

T[":TodoPicker falls back to vim.ui.select"] = function()
    package.loaded.snacks = false
    local select = vim.ui.select
    local shown
    vim.ui.select = function(items, opts, on_choice)
        shown = vim.tbl_map(opts.format_item, items)
        on_choice(items[3])
    end
    vim.cmd("TodoPicker")
    wait_for(function()
        return shown ~= nil
    end)
    vim.ui.select = select
    package.loaded.snacks = nil
    eq(shown, { "✓ a.lua:1: -- TODO: one", "! a.lua:3: -- FIXME: two", "ℹ sub/b.c:1: /* NOTE: three */" })
    eq(vim.fs.basename(vim.api.nvim_buf_get_name(0)), "b.c")
    eq(vim.api.nvim_win_get_cursor(0), { 1, 3 })
end

T[":TodoPicker uses snacks"] = function()
    local snacks_dir = H.root .. "/.tests/snacks.nvim"
    if vim.fn.isdirectory(snacks_dir) == 0 then
        MiniTest.skip("snacks.nvim not in .tests/")
    end
    vim.opt.runtimepath:append(snacks_dir)
    require("snacks").setup({ picker = { enabled = true } })

    local function texts(p)
        return vim.tbl_map(function(item)
            return item.todo.text
        end, p:items())
    end

    vim.cmd("TodoPicker")
    local p
    wait_for(function()
        p = Snacks.picker.get({ source = "todo" })[1]
        return p ~= nil and #p:items() == 3
    end)
    eq(texts(p), { "-- TODO: one", "-- FIXME: two", "/* NOTE: three */" })

    -- Cycle: all -> FIX -> NOTE -> TODO -> all
    p:action("todo_cycle_keyword")
    wait_for(function()
        return #p:items() == 1
    end)
    eq({ texts(p), p.title }, { { "-- FIXME: two" }, "Todos (FIX)" })
    p:action("todo_cycle_keyword")
    p:action("todo_cycle_keyword")
    p:action("todo_cycle_keyword")
    wait_for(function()
        return #p:items() == 3
    end)
    eq(p.title, "Todos")
    p:close()
end

return T
