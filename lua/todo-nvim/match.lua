local config = require("todo-nvim.config")

local M = {}

-- ASCII word characters, spelled out so the result does not depend on the
-- C library's locale (rg's `(?-u:\b)` uses the same set)
local WORD = "A-Za-z0-9_"

local function is_word_start(word)
    return word:find("^[" .. WORD .. "]") ~= nil
end

local function is_word_end(word)
    return word:find("[" .. WORD .. "]$") ~= nil
end

local default_words = {}

--- Words to match, longest first, optionally limited to some keyword names.
---@param names? string[] keyword names (e.g. { "TODO", "FIX" })
---@return string[]
function M.words(names)
    local lookup = config.get_lookup()
    if not names and default_words.lookup == lookup then
        return default_words.words
    end
    local wanted = names and {} or nil
    for _, name in ipairs(names or {}) do
        wanted[name] = true
    end
    local words = {}
    for word, kw in pairs(lookup) do
        if not wanted or wanted[kw.name] then
            table.insert(words, word)
        end
    end
    table.sort(words, function(a, b)
        if #a ~= #b then
            return #a > #b
        end
        return a < b
    end)
    if not names then
        -- setup() builds a new lookup table, which invalidates this cache
        default_words = { lookup = lookup, words = words }
    end
    return words
end

local lua_patterns = setmetatable({}, { __mode = "k" })

local function lua_pattern(word)
    local pattern = vim.pesc(word)
    if is_word_start(word) then
        pattern = "%f[" .. WORD .. "]" .. pattern
    end
    if is_word_end(word) then
        pattern = pattern .. "%f[^" .. WORD .. "]"
    end
    return pattern
end

local function patterns_for(words)
    local cached = lua_patterns[words]
    if not cached then
        cached = {}
        for _, word in ipairs(words) do
            table.insert(cached, { word = word, pattern = lua_pattern(word) })
        end
        lua_patterns[words] = cached
    end
    return cached
end

---@class todo.Match
---@field keyword string keyword name, e.g. "FIX" for "FIXME"
---@field word string the text that matched, e.g. "FIXME"
---@field start_col integer 0-indexed byte column
---@field end_col integer 0-indexed, exclusive

--- Find every keyword in a line, in column order.
---@param line string
---@param words? string[] from M.words(); defaults to all keywords
---@return todo.Match[]
function M.find(line, words)
    local lookup = config.get_lookup()
    local found = {}
    for _, p in ipairs(patterns_for(words or M.words())) do
        local init = 1
        while true do
            local s, e = line:find(p.pattern, init)
            if not s then
                break
            end
            table.insert(found, { keyword = lookup[p.word].name, word = p.word, start_col = s - 1, end_col = e })
            init = e + 1
        end
    end

    table.sort(found, function(a, b)
        if a.start_col ~= b.start_col then
            return a.start_col < b.start_col
        end
        return a.end_col > b.end_col
    end)

    -- Drop overlaps (e.g. a custom "TODO(me)" next to "TODO"), keeping the longest
    local result, last_end = {}, -1
    for _, m in ipairs(found) do
        if m.start_col >= last_end then
            table.insert(result, m)
            last_end = m.end_col
        end
    end
    return result
end

--- Escape a string for rg's (Rust) regex syntax.
local function rg_escape(str)
    return (str:gsub("[%\\%.%+%*%?%(%)%|%[%]%{%}%^%$%#%&%-%~]", "\\%0"))
end

--- The rg regex for the keywords, matching the same way as M.find().
---@param names? string[] keyword names to limit the search to
---@return string
function M.rg_pattern(names)
    local patterns = {}
    for _, word in ipairs(M.words(names)) do
        local pattern = rg_escape(word)
        if is_word_start(word) then
            pattern = "(?-u:\\b)" .. pattern
        end
        if is_word_end(word) then
            pattern = pattern .. "(?-u:\\b)"
        end
        table.insert(patterns, pattern)
    end
    return table.concat(patterns, "|")
end

-- Comment detection --------------------------------------------------------

local function node_in_comment(node)
    while node do
        -- Matches comment, line_comment, block_comment, doc_comment, ...
        if node:type():find("comment", 1, true) then
            return true
        end
        node = node:parent()
    end
    return false
end

--- Check a position against a parsed LanguageTree, including injections.
local function tree_in_comment(parser, row, col)
    local range = { row, col, row, col + 1 }
    local ltree = parser:language_for_range(range)
    while ltree do
        -- Text inside a comment injection (the `comment` parser) is a comment
        if ltree:lang() == "comment" then
            return true
        end
        local node = ltree:named_node_for_range(range, { ignore_injections = true })
        if node_in_comment(node) then
            return true
        end
        -- An injected language may sit inside a comment of its host language
        ltree = ltree:parent()
    end
    return false
end

--- The comment prefix from a 'commentstring', e.g. "-- %s" -> "--".
local function comment_prefix(commentstring)
    if type(commentstring) ~= "string" then
        return nil
    end
    local prefix = vim.trim(commentstring:match("^(.-)%%s") or "")
    return prefix ~= "" and prefix or nil
end

--- Checker that looks for the comment prefix before the column. Without a
--- prefix, every position counts as a comment.
---@param get_line fun(row: integer): string|nil
local function prefix_checker(commentstring, get_line)
    local prefix = comment_prefix(commentstring)
    return function(row, col)
        if not prefix then
            return true
        end
        local line = get_line(row)
        return line ~= nil and line:sub(1, col):find(prefix, 1, true) ~= nil
    end
end

local function get_lang(filetype)
    if not filetype or filetype == "" then
        return nil
    end
    return vim.treesitter.language.get_lang(filetype)
end

--- Treesitter parser for a buffer, or nil.
function M.buf_parser(bufnr)
    local lang = get_lang(vim.bo[bufnr].filetype)
    if not lang then
        return nil
    end
    local ok, parser = pcall(vim.treesitter.get_parser, bufnr, lang, { error = false })
    return ok and parser or nil
end

---@alias todo.CommentChecker fun(row: integer, col: integer): boolean

--- Comment checker for a buffer. Parses the given rows (0-indexed,
--- end-exclusive) once; check positions inside that range only.
---@param bufnr integer
---@param first? integer
---@param last? integer
---@return todo.CommentChecker
function M.buf_checker(bufnr, first, last)
    local parser = M.buf_parser(bufnr)
    if parser then
        parser:parse(first and { first, last } or true)
        return function(row, col)
            return tree_in_comment(parser, row, col)
        end
    end
    return prefix_checker(vim.bo[bufnr].commentstring, function(row)
        return vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    end)
end

--- Comment checker for a file's text, without creating a buffer.
---@param path string
---@param read fun(): string|nil returns the whole file, called only when a parser is available
---@param get_line fun(row: integer): string|nil used by the 'commentstring' fallback
---@return todo.CommentChecker
function M.file_checker(path, read, get_line)
    local ft = vim.filetype.match({ filename = path })
    local lang = get_lang(ft)
    if lang then
        local text = read()
        local ok, parser = pcall(vim.treesitter.get_string_parser, text or "", lang, { error = false })
        if text and ok and parser then
            parser:parse(true)
            return function(row, col)
                return tree_in_comment(parser, row, col)
            end
        end
    end
    local commentstring = ft and vim.filetype.get_option(ft, "commentstring") or nil
    return prefix_checker(commentstring, get_line)
end

--- Whether a position (0-indexed) in a buffer is inside a comment.
function M.in_comment(bufnr, row, col)
    return M.buf_checker(bufnr, row, row + 1)(row, col)
end

return M
