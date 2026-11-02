local M = {}

M.defaults = {
    -- Each keyword has an icon (sign text, 1-2 cells), a highlight group, and
    -- optional alternative spellings that map to the same keyword.
    keywords = {
        TODO = { icon = "✓", hl = "TodoTODO", alt = { "@todo" } },
        FIX = { icon = "!", hl = "TodoFIX", alt = { "FIXME" } },
        BUG = { icon = "✗", hl = "TodoBUG" },
        HACK = { icon = "⚡", hl = "TodoHACK" },
        WARN = { icon = "⚠", hl = "TodoWARN", alt = { "WARNING" } },
        NOTE = { icon = "ℹ", hl = "TodoNOTE", alt = { "INFO" } },
        PERF = { icon = "⏱", hl = "TodoPERF", alt = { "OPTIMIZE" } },
        XXX = { icon = "✗", hl = "TodoXXX" },
    },
    -- false = user's keywords replace the defaults entirely
    merge_keywords = true,
    search_paths = { "." },
    -- "cwd" | "git"
    search_root = "cwd",
    signs = true,
    keymap = false,
    debounce_ms = 150,
    -- Only show picker/quickfix results that are inside comments
    filter_comments = true,
}

---@type table|nil
M.options = nil

-- Every word (keyword name and alt spellings) -> { name, icon, hl }
---@type table<string, { name: string, icon: string, hl: string }>
M.lookup = {}

local function is_string_list(v)
    if type(v) ~= "table" or not vim.islist(v) then
        return false
    end
    for _, s in ipairs(v) do
        if type(s) ~= "string" or s == "" then
            return false
        end
    end
    return true
end

local validators = {
    keywords = function(v)
        return type(v) == "table", "a table"
    end,
    merge_keywords = function(v)
        return type(v) == "boolean", "a boolean"
    end,
    search_paths = function(v)
        return is_string_list(v) and #v > 0, "a non-empty list of strings"
    end,
    search_root = function(v)
        return v == "cwd" or v == "git", '"cwd" or "git"'
    end,
    signs = function(v)
        return type(v) == "boolean", "a boolean"
    end,
    keymap = function(v)
        return v == false or (type(v) == "string" and v ~= ""), "false or a key sequence"
    end,
    debounce_ms = function(v)
        return type(v) == "number" and v >= 0, "a number >= 0"
    end,
    filter_comments = function(v)
        return type(v) == "boolean", "a boolean"
    end,
}

local function validate_keyword(name, kw)
    if type(name) ~= "string" or name == "" then
        return "keyword names must be non-empty strings"
    end
    if type(kw) ~= "table" then
        return ("keywords.%s must be a table"):format(name)
    end
    if type(kw.icon) ~= "string" or kw.icon == "" then
        return ("keywords.%s.icon must be a non-empty string"):format(name)
    end
    if vim.fn.strdisplaywidth(kw.icon) > 2 then
        return ("keywords.%s.icon must be at most 2 cells wide"):format(name)
    end
    if kw.hl ~= nil and (type(kw.hl) ~= "string" or kw.hl == "") then
        return ("keywords.%s.hl must be a highlight group name"):format(name)
    end
    if kw.alt ~= nil and not is_string_list(kw.alt) then
        return ("keywords.%s.alt must be a list of strings"):format(name)
    end
end

--- Default highlight group for a keyword name, e.g. "TODO" -> "TodoTODO".
function M.default_hl(name)
    return "Todo" .. name:gsub("[^%w_]", "_")
end

--- Merge user options over the defaults. Lists replace, they never merge by index.
---@return table options, string[] errors
function M.merge(opts)
    opts = opts or {}
    local errors = {}
    local options = vim.deepcopy(M.defaults)

    for key, value in pairs(opts) do
        local check = validators[key]
        if not check then
            table.insert(errors, ("unknown option %q"):format(tostring(key)))
        else
            local ok, expected = check(value)
            if ok then
                if key ~= "keywords" then
                    options[key] = vim.deepcopy(value)
                end
            else
                table.insert(errors, ("%s must be %s"):format(key, expected))
            end
        end
    end

    local user_keywords = type(opts.keywords) == "table" and opts.keywords or nil
    if user_keywords then
        if options.merge_keywords == false then
            options.keywords = {}
        end
        for name, kw in pairs(user_keywords) do
            if kw == false then
                -- `FIX = false` removes a default keyword
                options.keywords[name] = nil
            elseif type(kw) == "table" then
                options.keywords[name] = vim.tbl_extend("force", options.keywords[name] or {}, vim.deepcopy(kw))
            else
                options.keywords[name] = kw
            end
        end
    end

    for name, kw in pairs(options.keywords) do
        local err = validate_keyword(name, kw)
        if err then
            table.insert(errors, err)
            options.keywords[name] = nil
        else
            kw.hl = kw.hl or M.default_hl(name)
            kw.alt = kw.alt or {}
        end
    end

    return options, errors
end

--- Build the word -> keyword lookup table.
---@return table lookup, string[] errors
function M.build_lookup(keywords)
    local lookup, errors = {}, {}
    local names = vim.tbl_keys(keywords)
    table.sort(names)
    for _, name in ipairs(names) do
        local kw = keywords[name]
        local entry = { name = name, icon = kw.icon, hl = kw.hl }
        for _, word in ipairs(vim.list_extend({ name }, kw.alt)) do
            if lookup[word] and lookup[word].name ~= name then
                table.insert(errors, ("%q is used by both %s and %s"):format(word, lookup[word].name, name))
            else
                lookup[word] = entry
            end
        end
    end
    return lookup, errors
end

--- Validate options without applying them.
---@return string[] errors
function M.validate(opts)
    local options, errors = M.merge(opts)
    local _, lookup_errors = M.build_lookup(options.keywords)
    return vim.list_extend(errors, lookup_errors)
end

-- The raw opts passed to the last setup() call, kept for :checkhealth
M.user_opts = nil

function M.setup(opts)
    M.user_opts = opts or {}
    local options, errors = M.merge(opts)
    local lookup, lookup_errors = M.build_lookup(options.keywords)
    vim.list_extend(errors, lookup_errors)

    M.options = options
    M.lookup = lookup

    if #errors > 0 then
        vim.notify("todo-nvim: invalid config:\n- " .. table.concat(errors, "\n- "), vim.log.levels.WARN)
    end

    require("todo-nvim.highlights").apply()
end

--- Options, calling setup({}) first if it was never called.
function M.get()
    if not M.options then
        M.setup({})
    end
    return M.options
end

--- Word lookup table, calling setup({}) first if it was never called.
function M.get_lookup()
    M.get()
    return M.lookup
end

--- Sorted list of keyword names.
function M.keyword_names()
    local names = vim.tbl_keys(M.get().keywords)
    table.sort(names)
    return names
end

return M
