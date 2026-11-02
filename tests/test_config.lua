local config = require("todo-nvim.config")
local eq = MiniTest.expect.equality

local T = MiniTest.new_set({
    hooks = {
        pre_case = function()
            config.options = nil
            config.lookup = {}
        end,
    },
})

T["merge"] = MiniTest.new_set()

T["merge"]["uses defaults with no opts"] = function()
    local opts, errors = config.merge()
    eq(errors, {})
    eq(opts.search_paths, { "." })
    eq(opts.keywords.TODO.icon, "✓")
    eq(opts.keymap, false)
end

T["merge"]["replaces lists instead of merging by index"] = function()
    local opts = config.merge({ search_paths = { "src" } })
    eq(opts.search_paths, { "src" })

    opts = config.merge({ keywords = { TODO = { alt = { "@later" } } } })
    eq(opts.keywords.TODO.alt, { "@later" })
end

T["merge"]["merges keywords with defaults"] = function()
    local opts = config.merge({ keywords = { TODO = { icon = "T" }, IDEA = { icon = "?" } } })
    eq(opts.keywords.TODO.icon, "T")
    eq(opts.keywords.TODO.hl, "TodoTODO")
    eq(opts.keywords.TODO.alt, { "@todo" })
    eq(opts.keywords.IDEA, { icon = "?", hl = "TodoIDEA", alt = {} })
    eq(opts.keywords.FIX ~= nil, true)
end

T["merge"]["merge_keywords = false replaces the defaults"] = function()
    local opts = config.merge({ merge_keywords = false, keywords = { IDEA = { icon = "?" } } })
    eq(vim.tbl_keys(opts.keywords), { "IDEA" })
end

T["merge"]["false removes a keyword"] = function()
    local opts = config.merge({ keywords = { FIX = false } })
    eq(opts.keywords.FIX, nil)
end

T["merge"]["reports bad input and drops bad keywords"] = function()
    local opts, errors = config.merge({
        search_root = "home",
        nope = 1,
        keywords = { BAD = { hl = "Error" }, WIDE = { icon = "abc" } },
    })
    eq(opts.search_root, "cwd")
    eq(opts.keywords.BAD, nil)
    eq(opts.keywords.WIDE, nil)
    eq(#errors, 4)
end

T["lookup"] = MiniTest.new_set()

T["lookup"]["maps keywords and alt names"] = function()
    config.setup({})
    eq(config.lookup.TODO, { name = "TODO", icon = "✓", hl = "TodoTODO" })
    eq(config.lookup["@todo"].name, "TODO")
    eq(config.lookup.FIXME.name, "FIX")
    eq(config.lookup.WARNING.name, "WARN")
end

T["lookup"]["reports duplicate words"] = function()
    local errors = config.validate({ keywords = { FIXIT = { icon = "!", alt = { "FIXME" } } } })
    eq(#errors, 1)
end

T["get"] = MiniTest.new_set()

T["get"]["calls setup lazily"] = function()
    eq(config.options, nil)
    eq(config.get().search_root, "cwd")
    eq(config.get_lookup().BUG.name, "BUG")
end

return T
