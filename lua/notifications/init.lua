local M = {}

function M.setup() end

---@enum notifications.DisplayType
M.displayType = {
    BALLOON = 1,
    STICKY_BALLOON = 2,
    TOOL_WINDOW_BALLOON = 3,
    NO_POPUP = 4,
}

M.level_names = {
    [0] = "TRACE",
    [1] = "DEBUG",
    [2] = "INFO",
    [3] = "WARN",
    [4] = "ERROR",
    [5] = "OFF",
}

---@class notifications.Options
---@field title string|nil
---@field type notifications.DisplayType|nil
---@field icon string|nil
---@field timeout number|boolean|nil Time to show notification in milliseconds, set to false to disable timeout.

--- Displays a notification to the user.
---@param msg string Content of the notification to show to the user.
---@param level vim.log.levels|nil One of the values from |vim.log.levels|.
---@param opts notifications.Options|nil Optional parameters. Unused by default.
---@diagnostic disable-next-line: unused-local
function M.notify(msg, level, opts)
    msg = msg or ""
    level = level or vim.log.levels.INFO
    assert(type(M.level_names[level]) == "string", "Invalid log level: " .. tostring(level))

    local n = require("notifications.notification"):new("main", opts and opts.title or "", msg, level)
    -- n.notify()
    vim.notify(n:getContent())
end

return M
