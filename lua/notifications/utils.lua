local logger = require("notifications.logger")

---@class Utils
local M = {}

--- Invoking
local invokationQueue = {}
local invokationScheduled = false
local invokationErrors = {}

local function reportErrors()
    if #invokationErrors == 0 then
        return
    end
    local errors = table.concat(invokationErrors, "\n")
    invokationErrors = {}
    logger:error("Errors during notifications invokations:\n" .. errors)
end
local function invoke()
    local timer, step_delay = assert(vim.loop.new_timer()), 1
    local fn
    fn = vim.schedule_wrap(function()
        local callback = invokationQueue[1]
        if callback == nil then
            invokationScheduled, invokationQueue = false, {}
            ---@diagnostic disable-next-line: need-check-nil
            timer:close()
            reportErrors()
            return
        end

        table.remove(invokationQueue, 1)
        M.invokeNow(callback)
        timer:start(step_delay, 0, fn)
    end)
    ---@diagnostic disable-next-line: need-check-nil
    timer:start(step_delay, 0, fn)
end

local function scheduleIvokations()
    if invokationScheduled then
        return
    end
    vim.schedule(invoke)
    invokationScheduled = true
end

---@param runnable function
function M.invokeLater(runnable)
    table.insert(invokationQueue, runnable)
    scheduleIvokations()
end

---@param runnable function
function M.invokeNow(runnable)
    local ok, err = pcall(runnable)
    if not ok then
        table.insert(invokationErrors, "now: " .. tostring(err))
    end
    scheduleIvokations()
end

---@param str string|any
---@return boolean
function M.isEmptyStr(str)
    return type(str) ~= "string" or str:match("^%s*$") ~= nil
end

---@param text string
---@param max_width integer
---@param suffix? string|boolean
---@return string
function M.truncate(text, max_width, suffix)
    if type(text) ~= "string" or text == "" then
        return ""
    end
    if vim.fn.strdisplaywidth(text) <= max_width then
        return text
    end
    if suffix == nil or suffix == true then
        suffix = "…"
    elseif suffix == false then
        suffix = ""
    elseif type(suffix) ~= "string" then
        error("Invalid suffix: expected string, boolean or nil, got " .. type(suffix))
    end
    local target_width = max_width - vim.fn.strdisplaywidth(suffix)
    local result = ""
    local current_width = 0
    for i = 0, vim.fn.strchars(text) - 1 do
        local char = vim.fn.strcharpart(text, i, 1)
        local char_width = vim.fn.strdisplaywidth(char)
        if current_width + char_width > target_width then
            break
        end
        result = result .. char
        current_width = current_width + char_width
    end
    return result .. suffix
end

---@param text string
---@param max_width integer
---@param max_lines integer
---@param suffix string|boolean|nil
---@return string[] truncated wrapped text split into lines (limited to max_lines)
---@return string[] full all wrapped lines without max_lines limit
---@return boolean overflowed whether the text was truncated due to max_lines limit
function M.wrap(text, max_width, max_lines, suffix)
    if type(text) ~= "string" or max_lines <= 0 then
        return {}, {}, false
    end
    if text == "" then
        return { "" }, { "" }, false
    end

    if suffix == nil or suffix == true then
        suffix = "…"
    elseif suffix == false then
        suffix = ""
    elseif type(suffix) ~= "string" then
        error("Invalid suffix: expected string, boolean or nil, got " .. type(suffix))
    end

    local lines = {}
    local full_lines = {}
    local overflowed = false

    local function overflow()
        if #lines > 0 then
            local target_width = max_width - vim.fn.strdisplaywidth(suffix)
            local result = ""
            local current_width = 0
            for i = 0, vim.fn.strchars(lines[#lines]) - 1 do
                local char = vim.fn.strcharpart(lines[#lines], i, 1)
                local char_width = vim.fn.strdisplaywidth(char)
                if current_width + char_width > target_width then
                    break
                end
                result = result .. char
                current_width = current_width + char_width
            end
            lines[#lines] = result .. suffix
        end
    end

    local function push(line)
        table.insert(full_lines, line)
        if overflowed then
            return true
        end
        if #lines >= max_lines then
            overflow()
            overflowed = true
            return true
        end
        table.insert(lines, line)
        return true
    end

    local function splitLongWord(word)
        if vim.fn.strdisplaywidth(word) <= max_width then
            return { word }
        end

        local chunks = {}
        local chunk = ""
        local width = 0
        for i = 0, vim.fn.strchars(word) - 1 do
            local char = vim.fn.strcharpart(word, i, 1)
            local char_width = vim.fn.strdisplaywidth(char)
            if chunk ~= "" and width + char_width > max_width then
                table.insert(chunks, chunk)
                chunk = ""
                width = 0
            end
            chunk = chunk .. char
            width = width + char_width
        end
        if chunk ~= "" then
            table.insert(chunks, chunk)
        end
        return chunks
    end

    text = text:gsub("\r\n", "\n"):gsub("\r", "\n")

    for paragraph in (text .. "\n"):gmatch("(.-)\n") do
        local current = ""

        if paragraph == "" then
            push("")
        else
            for word in paragraph:gmatch("%S+") do
                for _, part in ipairs(splitLongWord(word)) do
                    local candidate = current == "" and part or current .. " " .. part
                    if vim.fn.strdisplaywidth(candidate) <= max_width then
                        current = candidate
                    else
                        push(current)
                        current = part
                    end
                end
            end

            if current ~= "" then
                push(current)
            end
        end
    end

    return lines, full_lines, overflowed
end

function M.instanceof(obj, class)
    if obj == nil or class == nil then
        return false
    end

    -- Only tables can have metatables
    if type(obj) ~= "table" then
        return false
    end

    local mt = getmetatable(obj)
    while mt do
        if mt == class then
            return true
        end

        -- Support both common inheritance patterns
        if mt.__index and mt.__index ~= mt then
            mt = mt.__index
        else
            mt = getmetatable(mt)
        end
    end

    return false
end

---@class notifications.DebouncedFunction
---@field cancel fun()
---@field close fun()

-- Debounce function to limit the rate at which a function can fire.
---@param ms integer
---@param fn fun(...)
---@return notifications.DebouncedFunction
function M.debounce(ms, fn)
    local timer = assert(vim.uv.new_timer())
    local argv = nil
    local pending = false
    local closed = false
    local unpack_args = unpack or table.unpack
    local wrapped = vim.schedule_wrap(function()
        if closed or not pending then
            argv = nil
            return
        end

        local args = argv
        argv = nil
        pending = false
        fn(unpack_args(args or {}))
    end)

    local debounced = {}

    function debounced.cancel()
        argv = nil
        pending = false
        if not timer:is_closing() then
            timer:stop()
        end
    end

    function debounced.close()
        argv = nil
        pending = false
        closed = true
        if not timer:is_closing() then
            timer:stop()
            timer:close()
        end
    end

    return setmetatable(debounced, {
        __call = function(_, ...)
            if closed or timer:is_closing() then
                return
            end

            argv = { ... }
            pending = true
            timer:stop()
            timer:start(ms, 0, wrapped)
        end,
    })
end

M.is_a = M.instanceof

---@param list table
---@param item any
---@return boolean removed true if item was found and removed, false otherwise
---@return integer count of removed items
function M.removeFromList(list, item)
    local count = 0
    for i = #list, 1, -1 do
        if list[i] == item then
            table.remove(list, i)
            count = count + 1
        end
    end
    return count > 0, count
end

return M
